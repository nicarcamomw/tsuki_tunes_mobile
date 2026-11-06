"""Turns a mask picture on a plain background into a mask image.

White backgrounds are cut by color (plus rembg when installed); dark ones
by rembg alone.

The background is what is white and reaches the picture's edges: white
parts inside the mask (a kitsune's face) stay. Edges are softened and the
white fringe is taken out of their color. The mask is then centered at the
size of the others: 510x637, transparent, about 85% of the width.

    python3 tool/add_mask.py <picture> <tier: r|sr|ssr|ul|dios> <name> [...]

Several masks at once: repeat the three arguments (the AI model loads once).

Writes assets/images/masks/<tier>/<name>.webp and keeps the original in
tool/mask_sources/<tier>/ (not in the app) to redo it at another size.

White parts of the mask that touch the background (a forehead's shine)
can't be told from it by color alone: with rembg installed
(pip install "rembg[cpu]"), its AI cut-out is added to the color one, and
a pixel stays when either keeps it.
"""

import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw

W, H = 510, 637
# The mask's box inside the image, like the original four.
FIT_W, FIT_H = 440, 560
TIERS = ('r', 'sr', 'ssr', 'ul', 'dios')

# --fill-holes: also remove pure white pockets enclosed by the mask.
FILL_HOLES = False

# --glow: keep a light glow around the mask as soft, see-through light
# (the AI cut-out plus how far each pixel is from white). For masks on a
# bright halo; it greys pure white faces, so it's off by default.
GLOW = False

# --solid: cut only the white the image edges reach, no AI: for white
# porcelain or glass masks whose white the AI would punch holes in.
SOLID = False

# How far from pure white (0-255, by the darkest channel) still counts as
# background, and where the soft edge ends.
BG_NEAR = 18
BG_FAR = 60


def cut_out(img: Image.Image) -> Image.Image:
    rgb = np.asarray(img.convert('RGB')).astype(np.float32)
    h, w, _ = rgb.shape
    if GLOW:
        ai = ai_alpha(img)
        if ai is None:
            raise SystemExit('--glow needs rembg installed')
        dist = 255 - rgb.min(axis=2)
        alpha = np.maximum(ai, np.clip((dist - 12) / 140, 0, 1) ** 1.3)
        a = np.maximum(alpha, 1e-3)[..., None]
        color = np.clip((rgb - (1 - a) * 255) / a, 0, 255)
        return Image.fromarray(np.dstack([color, alpha * 255]).astype(np.uint8), 'RGBA')
    # A dark background (not white): only the AI can tell the mask from it.
    corners = np.concatenate([rgb[:8, :8], rgb[:8, -8:], rgb[-8:, :8], rgb[-8:, -8:]]).reshape(-1, 3)
    if corners.min(axis=1).mean() < 128:
        ai = ai_alpha(img)
        if ai is None:
            raise SystemExit('dark background: needs rembg installed')
        return Image.fromarray(np.dstack([rgb, ai * 255]).astype(np.uint8), 'RGBA')
    # 0 = pure white, 255 = black.
    dist = 255 - rgb.min(axis=2)

    # Whitish pixels connected to the edges: flood-filled from every
    # border pixel that's whitish.
    candidate = Image.fromarray(np.where(dist < BG_FAR, 255, 0).astype(np.uint8)).copy()
    for x, y in [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + \
                [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]:
        if candidate.getpixel((x, y)) == 255:
            ImageDraw.floodfill(candidate, (x, y), 128)
    background = np.asarray(candidate) == 128

    # Alpha: opaque inside the mask; in the background, fades from the
    # near-white (gone) to the far edge (kept) for smooth edges.
    soft = np.clip((dist - BG_NEAR) / (BG_FAR - BG_NEAR), 0, 1)
    alpha = np.where(background, soft, 1.0)
    if FILL_HOLES:
        # Pure white pockets the edges can't reach (white showing between
        # a face and the cords around it). Off by default: white masks
        # (porcelain) have pure white areas of their own.
        pockets = Image.fromarray(np.where((dist < 14) & ~background, 255, 0).astype(np.uint8)).copy()
        seen = np.zeros((h, w), bool)
        for y in range(0, h, 4):
            for x in range(0, w, 4):
                if pockets.getpixel((x, y)) == 255 and not seen[y, x]:
                    ImageDraw.floodfill(pockets, (x, y), 64)
                    blob = np.asarray(pockets) == 64
                    seen |= blob
                    if blob.sum() > h * w * 0.0005:
                        background |= blob
                    pockets.paste(Image.fromarray(np.where(blob, 1, 0).astype(np.uint8)), mask=Image.fromarray((blob * 255).astype(np.uint8)))
        soft = np.clip((dist - BG_NEAR) / (BG_FAR - BG_NEAR), 0, 1)
        alpha = np.where(background, soft, 1.0)
    if SOLID:
        # White masks (porcelain, glass): the AI takes their white for
        # background. Only what the edges reach is cut.
        a = np.maximum(alpha, 1e-3)[..., None]
        color = np.clip((rgb - (1 - a) * 255) / a, 0, 255)
        return Image.fromarray(np.dstack([color, alpha * 255]).astype(np.uint8), 'RGBA')
    ai = ai_alpha(img)
    if ai is not None:
        alpha = np.maximum(alpha, np.where(background & (dist < 14), 0, ai))
        # Background the edges can't reach (white between cords, a floor
        # shadow): light, colorless, and background to the AI.
        light = (rgb.min(axis=2) > 150) & (rgb.max(axis=2) - rgb.min(axis=2) < 28)
        holes = light & (ai < 0.15)
        alpha = np.where(holes, ai, alpha)

    # Edge colors were mixed with white: take the white back out.
    a = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - (1 - a) * 255) / a, 0, 255)
    out = np.dstack([color, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, 'RGBA')


_session = None


def ai_alpha(img: Image.Image):
    """rembg's cut-out (0..1), or None when it isn't installed."""
    try:
        from rembg import new_session, remove
    except ImportError:
        print('rembg not installed: color cut-out only (white edges may go)')
        return None
    global _session
    if _session is None:
        _session = new_session('isnet-general-use')
    cut = remove(img.convert('RGB'), session=_session)
    return np.asarray(cut.getchannel('A')).astype(np.float32) / 255


def fit(img: Image.Image) -> Image.Image:
    box = img.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
    if box is None:
        raise SystemExit('no mask found: is the background white?')
    mask = img.crop(box)
    scale = min(FIT_W / mask.width, FIT_H / mask.height)
    mask = mask.resize((round(mask.width * scale), round(mask.height * scale)), Image.LANCZOS)
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(mask, ((W - mask.width) // 2, (H - mask.height) // 2))
    return canvas


def add(src: str, tier: str, name: str) -> str:
    """One picture into its tier folder; returns the image's path."""
    if tier not in TIERS:
        raise SystemExit(f'tier must be one of {TIERS}')
    out = f'assets/images/masks/{tier}/{name}.webp'
    os.makedirs(os.path.dirname(out), exist_ok=True)
    fit(cut_out(Image.open(src))).save(out, 'WEBP', quality=92, method=6)

    keep = f'tool/mask_sources/{tier}/{name}{os.path.splitext(src)[1].lower()}'
    os.makedirs(os.path.dirname(keep), exist_ok=True)
    if os.path.abspath(src) != os.path.abspath(keep):
        shutil.copyfile(src, keep)
    return out


def main():
    """add_mask.py <picture> <tier> <name> [<picture> <tier> <name> ...]"""
    global FILL_HOLES, GLOW, SOLID
    args = sys.argv[1:]
    if '--solid' in args:
        SOLID = True
        args.remove('--solid')
    if '--fill-holes' in args:
        FILL_HOLES = True
        args.remove('--fill-holes')
    if '--glow' in args:
        GLOW = True
        args.remove('--glow')
    if not args or len(args) % 3:
        raise SystemExit(__doc__)
    for i in range(0, len(args), 3):
        print(add(*args[i:i + 3]))


if __name__ == '__main__':
    main()
