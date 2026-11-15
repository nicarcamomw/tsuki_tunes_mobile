"""Cuts a mask's artwork out of its white background.

    python3 tool/mask_art/cut_out.py source.jpg assets/images/tsuki_mask.webp

Only the white connected to the picture's border goes (a flood fill), so
the mask's own white panels stay. The edge is softened: pixels next to the
background get an alpha from how white they are, with the white taken back
out of their colour. Then the picture is trimmed to the mask, given a thin
margin and scaled to HEIGHT pixels tall.
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

HEIGHT = 1100
BG_MIN = 244  # every channel at least this, and grey: background candidate


def main(src, out):
    img = np.array(Image.open(src).convert('RGB')).astype(np.float32)
    h, w, _ = img.shape
    lo = img.min(axis=2)
    hi = img.max(axis=2)
    candidate = (lo >= BG_MIN) & (hi - lo <= 12)

    # Flood fill from the border over the candidates.
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if candidate[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if candidate[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and candidate[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))

    # A soft edge: within two pixels of the background, alpha from whiteness.
    near = np.array(Image.fromarray((bg * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    edge = near & ~bg
    alpha = np.where(bg, 0.0, 1.0)
    soft = np.clip((255 - lo) / (255 - 200), 0, 1)
    alpha = np.where(edge, np.minimum(alpha, soft), alpha)
    # Take the white back out of the edge's colour (decontamination).
    a = np.clip(alpha, 1e-3, 1)[..., None]
    rgb = np.clip((img - (1 - a) * 255) / a, 0, 255)
    alpha = np.array(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)))

    rgba = np.dstack([rgb, alpha]).astype(np.uint8)
    ys, xs = np.where(alpha > 8)
    m = int(0.01 * h)
    box = (max(xs.min() - m, 0), max(ys.min() - m, 0), min(xs.max() + m, w), min(ys.max() + m, h))
    cut = Image.fromarray(rgba, 'RGBA').crop(box)
    cut = cut.resize((round(cut.width * HEIGHT / cut.height), HEIGHT), Image.LANCZOS)
    if out.endswith('.webp'):
        cut.save(out, 'WEBP', quality=92, method=6)
    else:
        cut.save(out, optimize=True)
    print(out, cut.size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
