#!/usr/bin/env python3
"""Maps loose design values in lib/presentation onto lib/core/theme/design_tokens.dart.

Re-runnable (it only touches literals, never tokens), so after merging a
branch that added new loose values, run it again:

    python3 tool/design_tokens/migrate.py fonts     # D-01 / D-02
    python3 tool/design_tokens/migrate.py radii     # D-03
    python3 tool/design_tokens/migrate.py durations # D-04

Then `dart format` is not needed (lines keep their shape) and
`flutter analyze` must stay clean.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
LIB = os.path.normpath(os.path.join(ROOT, 'lib'))
TOKENS = os.path.join(LIB, 'core', 'theme', 'design_tokens.dart')
TARGETS = [os.path.join(LIB, 'presentation'), os.path.join(LIB, 'core', 'theme')]


def font_token(v):
    """Nearest step; ties go up (legibility first). Below 10 → micro (D-02)."""
    if v <= 10.25:
        return 'micro'
    table = [(11, 'caption'), (12, 'body'), (13, 'bodyLg'), (14, 'title'),
             (16, 'titleLg'), (22, 'headline'), (28, 'display'), (40, 'hero'), (64, 'mega')]
    if v >= 300:
        return None  # watermark glyphs: built from mega by hand
    best = None
    for size, name in table:
        d = abs(size - v)
        if best is None or d < best[0] or (d == best[0] and size > best[1]):
            best = (d, size, name)
    return best[2]


def radius_token(v):
    """By band: up to 6 a chip, up to 14 a card, up to 24 a sheet, beyond a pill."""
    if v <= 0:
        return None
    if v <= 6:
        return 'chip'
    if v <= 14:
        return 'card'
    if v <= 24:
        return 'sheet'
    return 'pill'


def rel_import(path):
    rel = os.path.relpath(TOKENS, os.path.dirname(path)).replace(os.sep, '/')
    return f"import '{rel}';"


def library_of(path, text):
    """A `part of` file can't import: its library does."""
    m = re.search(r"^part of '([^']+)';", text, re.M)
    if not m:
        return path
    return os.path.normpath(os.path.join(os.path.dirname(path), m.group(1)))


def add_import(path):
    text = open(path).read()
    if 'design_tokens.dart' in text:
        return
    imp = rel_import(path)
    lines = text.split('\n')
    imports = [i for i, l in enumerate(lines) if l.startswith('import ')]
    rel = [i for i in imports if not re.match(r"import '(package|dart):", lines[i])]
    if rel:
        pos = None
        for i in rel:
            if lines[i] > imp:
                pos = i
                break
        if pos is None:
            pos = rel[-1] + 1
            # A multi-line import (show/hide on the next lines).
            while not lines[pos - 1].rstrip().endswith(';'):
                pos += 1
    elif imports:
        pos = imports[-1] + 1
        while not lines[pos - 1].rstrip().endswith(';'):
            pos += 1
        lines.insert(pos, '')
        pos += 1
    else:
        pos = 0
        while pos < len(lines) and (lines[pos].startswith('//') or lines[pos].startswith('library')):
            pos += 1
    lines.insert(pos, imp)
    open(path, 'w').write('\n'.join(lines))


def migrate(kind):
    changed = set()
    for base in TARGETS:
        for dirpath, _, files in os.walk(base):
            for f in files:
                if not f.endswith('.dart') or f.endswith('.g.dart') or f == 'design_tokens.dart':
                    continue
                path = os.path.join(dirpath, f)
                text = open(path).read()
                new = text
                if kind == 'fonts':
                    def rep(m):
                        tok = font_token(float(m.group(2)))
                        return m.group(0) if tok is None else f'{m.group(1)}AppFontSize.{tok}'
                    new = re.sub(r'(fontSize: *)(\d+(?:\.\d+)?)(?![\d.])', rep, new)
                    # `cond ? 10 : 12` after fontSize:
                    def rep_cond(m):
                        a, b = font_token(float(m.group(3))), font_token(float(m.group(4)))
                        return f'{m.group(1)}{m.group(2)} ? AppFontSize.{a} : AppFontSize.{b}'
                    new = re.sub(r'(fontSize: *)([\w.!= ]+?) \? (\d+(?:\.\d+)?) : (\d+(?:\.\d+)?)(?![\d.])', rep_cond, new)
                    # Local style helpers: `TextStyle t(double size, ...)` called as t(9, ...).
                    for name in re.findall(r'TextStyle(?: Function\(double size[^)]*\)\s+|\s+)(\w+)\(?\s*(?:double size)?', new):
                        def rep_call(m):
                            tok = font_token(float(m.group(2)))
                            return m.group(0) if tok is None else f'{m.group(1)}AppFontSize.{tok}'
                        new = re.sub(r'((?<![\w])' + re.escape(name) + r'\( *)(\d+(?:\.\d+)?)(?![\d.])', rep_call, new)
                elif kind == 'radii':
                    def rep(m):
                        tok = radius_token(float(m.group(2)))
                        return m.group(0) if tok is None else f'{m.group(1)}AppRadius.{tok})'
                    new = re.sub(r'(BorderRadius\.circular\( *)(\d+(?:\.\d+)?)\)', rep, new)
                    def rep_c(m):
                        tok = radius_token(float(m.group(2)))
                        return m.group(0) if tok is None else f'{m.group(1)}AppRadius.{tok})'
                    new = re.sub(r'(Radius\.circular\( *)(\d+(?:\.\d+)?)\)', rep_c, new)
                    # A corner radius passed by name (SkeletonLoader, GlassCard,
                    # covers): `borderRadius: 6`, `this.borderRadius = 10`.
                    # Half the height on the same line is a pill.
                    def rep_named(m):
                        v = float(m.group(2))
                        line = new[new.rfind('\n', 0, m.start()) + 1:new.find('\n', m.end())]
                        h = re.search(r'height: *(\d+(?:\.\d+)?)', line)
                        tok = 'pill' if h and abs(float(h.group(1)) / 2 - v) < 0.01 else radius_token(v)
                        return m.group(0) if tok is None else f'{m.group(1)}AppRadius.{tok}'
                    new = re.sub(r'((?:borderRadius|this\.borderRadius)(?:: *| = ))(\d+(?:\.\d+)?)(?![\d.])', rep_named, new)
                    if '_Cover(' in new:
                        new = re.sub(r'(_Cover\([^;]*?radius: *)(\d+(?:\.\d+)?)(?![\d.])',
                                     lambda m: m.group(0) if radius_token(float(m.group(2))) is None
                                     else f'{m.group(1)}AppRadius.{radius_token(float(m.group(2)))}', new)
                        new = re.sub(r'(this\.radius = )(\d+(?:\.\d+)?)', lambda m: f'{m.group(1)}AppRadius.{radius_token(float(m.group(2)))}', new)
                if new != text:
                    open(path, 'w').write(new)
                    changed.add(library_of(path, new))
    for path in changed:
        add_import(path)
    print(f'{kind}: {len(changed)} libraries changed')


if __name__ == '__main__':
    for k in sys.argv[1:] or ['fonts']:
        migrate(k)
