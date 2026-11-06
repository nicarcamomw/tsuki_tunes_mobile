import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// The red the beings' names are written in.
const loreNameColor = Color(0xFFFF3B47);

/// A paragraph of the lore. Beings' names, written [[Like This]], read in
/// red capitals that glitch now and then, barely.
class LoreText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  const LoreText(this.text, {super.key, required this.style, this.textAlign = TextAlign.start});

  static final _name = RegExp(r'\[\[([^\]]+)\]\]');

  /// [text] without the name marks, for screen readers and tests.
  static String plain(String text) => text.replaceAllMapped(_name, (m) => m.group(1)!.toUpperCase());

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var at = 0;
    for (final m in _name.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GlitchName(m.group(1)!, style: style),
      ));
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Semantics(
      label: plain(text),
      excludeSemantics: true,
      child: Text.rich(TextSpan(style: style, children: spans), textAlign: textAlign),
    );
  }
}

/// A name in red capitals. Every few seconds it slips for a fraction of a
/// second: a red and a cyan ghost pull apart and snap back.
class GlitchName extends StatefulWidget {
  final String name;
  final TextStyle style;
  const GlitchName(this.name, {super.key, required this.style});

  @override
  State<GlitchName> createState() => _GlitchNameState();
}

class _GlitchNameState extends State<GlitchName> with SingleTickerProviderStateMixin {
  late final AnimationController _glitch =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  final _rng = Random();
  Timer? _next;
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _next?.cancel();
    if (!_still) _schedule();
  }

  void _schedule() {
    _next = Timer(Duration(milliseconds: 2500 + _rng.nextInt(4500)), () async {
      if (!mounted) return;
      await _glitch.forward(from: 0);
      if (mounted) _schedule();
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    _glitch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style.copyWith(
      color: loreNameColor,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
    final text = widget.name.toUpperCase();
    return AnimatedBuilder(
      animation: _glitch,
      builder: (context, _) {
        // A short triangle: out and back within the 180 ms.
        final t = _glitch.isAnimating ? 1 - (2 * _glitch.value - 1).abs() : 0.0;
        final split = 0.6 + 1.4 * t;
        final dx = t == 0 ? 0.0 : (_rng.nextBool() ? 1.0 : -1.0) * t;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Text(
            text,
            style: base.copyWith(shadows: [
              Shadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.30 + 0.3 * t), offset: Offset(-split, 0)),
              Shadow(color: const Color(0xFFFF2BD6).withValues(alpha: 0.22 + 0.3 * t), offset: Offset(split, 0)),
              Shadow(color: loreNameColor.withValues(alpha: 0.35), blurRadius: 6),
            ]),
          ),
        );
      },
    );
  }
}
