"""Builds the extra mask illustrations from the four original ones.

Each style redraws a mask in a different technique (gold-mended cracks,
hologram, ink, glitch, pixel art, neon outline, two masks fused, gold, ice,
sakura), not just a recolor. Run from the repo root:

    python3 tool/mask_styles.py

Writes assets/images/masks/<style>.webp (510x637, transparent).
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC = 'assets/images'
OUT = 'assets/images/masks'
W, H = 510, 637
KANJI_FONT = '/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf'


def load(name):
    return np.asarray(Image.open(f'{SRC}/{name}.png').convert('RGBA')).astype(np.float32) / 255


def to_image(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), 'RGBA')


def lum(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def edges(a, strength=4.0):
    """Sobel magnitude of the luminance, inside the mask, 0..1."""
    y = lum(a) * a[..., 3]
    gx = (np.roll(y, -1, 1) - np.roll(y, 1, 1)) * 2 + \
        (np.roll(np.roll(y, -1, 1), 1, 0) - np.roll(np.roll(y, 1, 1), 1, 0)) + \
        (np.roll(np.roll(y, -1, 1), -1, 0) - np.roll(np.roll(y, 1, 1), -1, 0))
    gy = (np.roll(y, -1, 0) - np.roll(y, 1, 0)) * 2 + \
        (np.roll(np.roll(y, -1, 0), 1, 1) - np.roll(np.roll(y, 1, 0), 1, 1)) + \
        (np.roll(np.roll(y, -1, 0), -1, 1) - np.roll(np.roll(y, 1, 0), -1, 1))
    return np.clip(np.hypot(gx, gy) * strength, 0, 1)


def gradient_map(t, stops):
    """Maps 0..1 values through color stops [(pos, (r,g,b)), ...]."""
    out = np.zeros(t.shape + (3,), np.float32)
    pos = [p for p, _ in stops]
    cols = [np.array(c, np.float32) / 255 for _, c in stops]
    for i in range(3):
        out[..., i] = np.interp(t, pos, [c[i] for c in cols])
    return out


def blur(a, radius):
    return np.asarray(to_image(a).filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255


def over(top, bottom):
    """Alpha-composites top over bottom (straight alpha)."""
    ta, ba = top[..., 3:4], bottom[..., 3:4]
    oa = ta + ba * (1 - ta)
    rgb = (top[..., :3] * ta + bottom[..., :3] * ba * (1 - ta)) / np.maximum(oa, 1e-6)
    return np.concatenate([rgb, oa], -1)


def layer(rgb, alpha):
    return np.concatenate([rgb, alpha[..., None]], -1)


def solid(color, alpha):
    rgb = np.ones(alpha.shape + (3,), np.float32) * (np.array(color, np.float32) / 255)
    return layer(rgb, alpha)


def stamp(img, kanji, xy, size, color=(200, 20, 30)):
    """A square hanko seal with a white kanji."""
    d = ImageDraw.Draw(img)
    x, y = xy
    d.rounded_rectangle([x, y, x + size, y + size], radius=size // 8, fill=color + (235,))
    font = ImageFont.truetype(KANJI_FONT, int(size * 0.72))
    box = d.textbbox((0, 0), kanji, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    d.text((x + (size - tw) / 2 - box[0], y + (size - th) / 2 - box[1]), kanji,
           font=font, fill=(255, 245, 235, 255))
    return img


# ─────────────────────────────────────────────────────────────────────────────


def kintsugi():
    """Porcelain kabuki mended with gold: glowing golden cracks."""
    a = load('oni')
    alpha = a[..., 3]
    l = lum(a)
    porcelain = gradient_map(l, [(0, (24, 24, 32)), (0.45, (150, 146, 140)), (1, (240, 236, 228))])
    rgb = porcelain * 0.8 + a[..., :3] * 0.2
    base = layer(rgb, alpha)

    rnd = random.Random(7)
    crack = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(crack)
    ys, xs = np.nonzero(alpha > 0.9)

    def walk(x, y, ang, length, width):
        for _ in range(length):
            nx = x + math.cos(ang) * 9
            ny = y + math.sin(ang) * 9
            d.line([x, y, nx, ny], fill=255, width=width)
            x, y = nx, ny
            ang += rnd.uniform(-0.6, 0.6)
            if rnd.random() < 0.08 and width > 2:
                walk(x, y, ang + rnd.choice([-1, 1]) * rnd.uniform(0.6, 1.2), length // 2, width - 1)

    # One crack starting in each part of the face, so they spread out.
    cx, cy = xs.mean(), ys.mean()
    for k in range(8):
        ang = k / 8 * 2 * math.pi
        x0 = cx + math.cos(ang) * 60
        y0 = cy + math.sin(ang) * 80
        walk(x0, y0, ang + rnd.uniform(-0.5, 0.5), rnd.randint(12, 22), 5)
    c = np.asarray(crack).astype(np.float32) / 255 * alpha
    glow = blur(solid((255, 190, 60), c), 6)[..., 3] * 1.4
    out = over(solid((255, 170, 40), np.clip(glow, 0, 0.8) * alpha), base)
    gold = gradient_map(np.clip(c, 0, 1), [(0, (200, 140, 30)), (1, (255, 236, 160))])
    out = over(layer(gold, c), out)
    return to_image(out)


def hologram():
    """Cyber oni as a cyan hologram: glowing outline, faint body, scanlines."""
    a = load('cyber_oni_mask')
    alpha = a[..., 3]
    e = edges(a, 5)
    body = solid((0, 200, 255), alpha * (0.12 + lum(a) * 0.35))
    lines = solid((120, 240, 255), e * alpha)
    glow = blur(solid((0, 229, 255), e * alpha), 5)
    ghost = solid((255, 40, 160), np.roll(e * alpha, -4, 1) * 0.55)
    out = over(lines, over(ghost, over(glow, body)))
    scan = np.ones((H, 1), np.float32)
    scan[::3] = 0.45
    out[..., 3] *= scan
    return to_image(out)


def sumie():
    """Kabuki painted in sumi ink washes on paper, with a red seal."""
    a = load('oni')
    alpha = a[..., 3]
    l = np.clip((lum(a) - 0.05) * 1.35, 0, 1)
    levels = np.round(l * 4) / 4
    ink = gradient_map(levels,
                       [(0, (16, 16, 18)), (0.25, (52, 50, 48)), (0.5, (118, 112, 104)),
                        (0.75, (196, 188, 174)), (1, (246, 240, 226))])
    paper = blur(layer(ink, alpha), 0.7)
    img = to_image(paper)
    return stamp(img, '墨', (W - 118, H - 160), 76)


def glitch():
    """Tengu torn by a broken signal: split channels and shifted slices."""
    a = load('tengu')
    out = np.zeros_like(a)
    out[..., 0] = np.roll(a[..., 0] * a[..., 3], 7, 1)
    out[..., 1] = a[..., 1] * a[..., 3]
    out[..., 2] = np.roll(a[..., 2] * a[..., 3], -7, 1)
    out[..., 3] = np.maximum.reduce([np.roll(a[..., 3], 7, 1), a[..., 3], np.roll(a[..., 3], -7, 1)])
    rgb = out[..., :3] / np.maximum(out[..., 3:4], 1e-6)
    out = np.concatenate([np.clip(rgb, 0, 1), out[..., 3:4]], -1)
    rnd = random.Random(3)
    for _ in range(9):
        y0 = rnd.randrange(60, H - 60)
        h = rnd.randint(6, 26)
        out[y0:y0 + h] = np.roll(out[y0:y0 + h], rnd.choice([-1, 1]) * rnd.randint(12, 34), 1)
    for _ in range(5):
        y0 = rnd.randrange(80, H - 80)
        h = rnd.randint(2, 5)
        color = rnd.choice([(0, 229, 255), (255, 25, 120)])
        band = np.zeros((h, W), np.float32)
        x0 = rnd.randrange(40, W // 2)
        band[:, x0:x0 + rnd.randint(80, 220)] = 0.85
        out[y0:y0 + h] = over(solid(color, band), out[y0:y0 + h])
    return to_image(out)


def pixel():
    """Kabuki as 8-bit pixel art."""
    img = Image.open(f'{SRC}/oni.png').convert('RGBA')
    small = img.resize((51, 64), Image.BOX)
    arr = np.asarray(small).astype(np.float32) / 255
    alpha = (arr[..., 3] > 0.5).astype(np.float32)
    rgb = Image.fromarray((arr[..., :3] * 255).astype(np.uint8), 'RGB').quantize(12).convert('RGB')
    small = layer(np.asarray(rgb).astype(np.float32) / 255, alpha)
    big = to_image(small).resize((510, 640), Image.NEAREST).crop((0, 2, 510, 639))
    return big


def neon():
    """Hannya drawn only with neon light, magenta to cyan."""
    a = load('hannya')
    alpha = a[..., 3]
    e = edges(a, 6)
    e = np.clip((e - 0.35) * 2.2, 0, 1)
    e = np.clip(blur(solid((255, 255, 255), e), 0.8)[..., 3] * 1.3, 0, 1) * alpha
    # The silhouette's own rim, always lit.
    rim = np.clip(edges(solid((255, 255, 255), alpha), 3) * 1.5, 0, 1)
    e = np.maximum(e, rim)
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None] * np.ones((1, W), np.float32)
    color = gradient_map(t, [(0, (255, 40, 200)), (0.55, (255, 25, 25)), (1, (0, 229, 255))])
    lines = layer(color, e)
    glow = blur(lines, 7)
    glow[..., 3] = np.clip(glow[..., 3] * 1.3, 0, 0.7)
    body = solid((8, 5, 12), alpha * 0.85)
    return to_image(over(layer(np.clip(color * 0.6 + 0.4, 0, 1), e), over(glow, body)))


def duo():
    """Hannya and kabuki fused down the middle, joined by a red seam."""
    left = load('hannya')
    right = load('oni')
    x = np.arange(W)[None, :]
    y = np.arange(H)[:, None]
    seam = W // 2 + (np.abs(((y // 18) % 2) * 18 - (y % 18)) - 9) * 0.9
    out = np.where((x < seam)[..., None], left, right)
    band = np.clip(1 - np.abs(x - seam) / 3, 0, 1) * np.maximum(left[..., 3], right[..., 3])
    glow = blur(solid((255, 30, 30), band), 6)
    glow[..., 3] = np.clip(glow[..., 3] * 2, 0, 0.9) * np.maximum(left[..., 3], right[..., 3])
    out = over(solid((255, 210, 200), band), over(glow, out))
    return to_image(out)


def gold():
    """Cyber oni cast in solid gold."""
    a = load('cyber_oni_mask')
    l = lum(a)
    rgb = gradient_map(l, [(0, (40, 22, 4)), (0.3, (120, 76, 14)), (0.6, (222, 166, 56)), (1, (255, 244, 196))])
    spec = np.clip((l - 0.6) * 3, 0, 1) ** 2
    rgb = np.clip(rgb + spec[..., None] * 0.35, 0, 1)
    return to_image(layer(rgb, a[..., 3]))


def ice():
    """Kabuki frozen into blue ice, with frost sparkles."""
    a = load('oni')
    alpha = a[..., 3]
    rgb = gradient_map(lum(a), [(0, (6, 20, 44)), (0.4, (30, 92, 170)), (0.75, (140, 210, 255)), (1, (255, 255, 255))])
    base = layer(rgb, alpha * 0.94)
    rnd = np.random.default_rng(5)
    specks = (rnd.random((H, W)) > 0.9975).astype(np.float32) * alpha
    sparkle = blur(solid((255, 255, 255), specks), 1.4)
    sparkle[..., 3] = np.clip(sparkle[..., 3] * 6, 0, 1)
    frost = blur(solid((220, 245, 255), edges(a, 3) * alpha), 2)
    frost[..., 3] *= 0.6
    return to_image(over(sparkle, over(frost, base)))


def sakura():
    """Hannya in pink with falling cherry petals."""
    a = load('hannya')
    alpha = a[..., 3]
    pink = gradient_map(lum(a), [(0, (40, 8, 22)), (0.5, (214, 92, 140)), (1, (255, 226, 238))])
    rgb = np.clip(pink * 0.75 + a[..., :3] * 0.25 + 0.05, 0, 1)
    img = to_image(layer(rgb, alpha))
    petals = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    rnd = random.Random(11)
    def petal(size, opacity):
        # Teardrop with the notch at the tip, like a real cherry petal.
        n = 40
        pts = []
        for i in range(n + 1):
            t = i / n * 2 * math.pi
            r = size * (0.55 + 0.45 * math.cos(t / 2) ** 2)
            pts.append((size + math.sin(t) * r * 0.62, size * 1.1 - math.cos(t) * r))
        p = Image.new('RGBA', (size * 2, size * 2 + 6), (0, 0, 0, 0))
        d = ImageDraw.Draw(p)
        d.polygon(pts, fill=(255, 190, 214, opacity))
        notch = [(size, size * 1.1 - size * 0.62), (size - size * 0.16, size * 0.05), (size + size * 0.16, size * 0.05)]
        d.polygon(notch, fill=(0, 0, 0, 0))
        d.line([(size, size * 1.65), (size, size * 0.75)], fill=(236, 120, 160, opacity), width=2)
        return p.filter(ImageFilter.GaussianBlur(0.6))

    for _ in range(16):
        side = rnd.random()
        x = rnd.choice([rnd.randrange(0, 120), rnd.randrange(W - 150, W - 40)]) if side < 0.7 else rnd.randrange(40, W - 60)
        y = rnd.randrange(0, H - 70)
        p = petal(rnd.randint(13, 22), rnd.randint(170, 245))
        p = p.rotate(rnd.uniform(0, 360), resample=Image.BICUBIC, expand=True)
        petals.alpha_composite(p, (min(x, W - p.width), min(y, H - p.height)))
    return Image.alpha_composite(img, petals)


STYLES = {
    'kintsugi': kintsugi,
    'hologram': hologram,
    'sumie': sumie,
    'glitch': glitch,
    'pixel': pixel,
    'neon': neon,
    'duo': duo,
    'gold': gold,
    'ice': ice,
    'sakura': sakura,
}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for name, build in STYLES.items():
        img = build()
        assert img.size == (W, H), (name, img.size)
        img.save(f'{OUT}/{name}.webp', 'WEBP', quality=88, method=6)
        print(name, os.path.getsize(f'{OUT}/{name}.webp') // 1024, 'KB')
