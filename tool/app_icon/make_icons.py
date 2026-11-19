"""App icons from the login's mask (assets/images/tsuki_mask.webp)."""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFilter

REPO = sys.argv[1]
MASK = Image.open(f'{REPO}/assets/images/tsuki_mask.webp').convert('RGBA')
BG = (0x18, 0x1B, 0x22, 255)
ACCENT = (0xE6, 0x39, 0x46)

# The mask's opaque pixels, for fitting it inside a circle.
alpha = MASK.split()[3]
bbox = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
mask = MASK.crop(bbox)
mw, mh = mask.size
a = mask.split()[3].load()
pts = [(x, y) for y in range(0, mh, 3) for x in range(0, mw, 3) if a[x, y] > 40]
cx, cy = mw / 2, mh / 2
far = max(math.hypot(x - cx, y - cy) for x, y in pts)  # in mask pixels

def glow(size, radius_frac, strength):
    """A soft crimson glow, as a radial falloff."""
    g = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    px = g.load()
    c = size / 2
    r = size * radius_frac
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / r
            if d < 1:
                al = int(255 * strength * (1 - d) ** 2)
                px[x, y] = (*ACCENT, al)
    return g

def mask_layer(size, circle_frac, mono=False):
    """The mask scaled so its farthest opaque pixel sits on a circle of
    circle_frac * size (radius), centred."""
    scale = (size * circle_frac) / far
    w, h = max(1, round(mw * scale)), max(1, round(mh * scale))
    m = mask.resize((w, h), Image.LANCZOS)
    if mono:
        white = Image.new('RGBA', m.size, (255, 255, 255, 255))
        white.putalpha(m.split()[3])
        m = white
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    # Optically centred: a touch lower, the horns weigh at the top.
    layer.alpha_composite(m, ((size - w) // 2, (size - h) // 2 + round(size * 0.01)))
    return layer

def shadow_under(size, layer):
    sh = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    a = layer.split()[3].filter(ImageFilter.GaussianBlur(size * 0.02))
    sh.putalpha(a.point(lambda v: int(v * 0.55)))
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(sh, (0, round(size * 0.012)))
    return out

res = f'{REPO}/android/app/src/main/res'
densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for d, k in densities.items():
    # Adaptive: 108 dp layers; the safe zone is a 33 dp radius circle.
    fs = round(108 * k)
    fg = Image.new('RGBA', (fs, fs), (0, 0, 0, 0))
    fg.alpha_composite(glow(fs, 0.38, 0.6))
    m = mask_layer(fs, 31 / 108)
    fg.alpha_composite(shadow_under(fs, m))
    fg.alpha_composite(m)
    fg.save(f'{res}/mipmap-{d}/ic_launcher_foreground.png', optimize=True)
    mask_layer(fs, 31 / 108, mono=True).save(f'{res}/mipmap-{d}/ic_launcher_monochrome.png', optimize=True)
    # Legacy (before Android 8): 48 dp, a rounded square.
    ls = round(48 * k)
    big = ls * 4
    leg = Image.new('RGBA', (big, big), BG)
    leg.alpha_composite(glow(big, 0.44, 0.6))
    m = mask_layer(big, 0.40)
    leg.alpha_composite(shadow_under(big, m))
    leg.alpha_composite(m)
    rounded = Image.new('L', (big, big), 0)
    ImageDraw.Draw(rounded).rounded_rectangle([0, 0, big - 1, big - 1], radius=big * 0.2, fill=255)
    leg.putalpha(rounded)
    leg.resize((ls, ls), Image.LANCZOS).save(f'{res}/mipmap-{d}/ic_launcher.png', optimize=True)

def full_square(size, frac=0.40, rounded=False):
    big = size * 2
    im = Image.new('RGBA', (big, big), BG)
    im.alpha_composite(glow(big, 0.44, 0.6))
    m = mask_layer(big, frac)
    im.alpha_composite(shadow_under(big, m))
    im.alpha_composite(m)
    return im.resize((size, size), Image.LANCZOS)

# iOS (no transparency allowed) and web.
ios = f'{REPO}/ios/Runner/Assets.xcassets/AppIcon.appiconset'
if os.path.isdir(ios):
    contents = json.load(open(f'{ios}/Contents.json'))
    cache = {}
    for img in contents['images']:
        fn = img.get('filename')
        if not fn:
            continue
        pt = float(img['size'].split('x')[0])
        px = round(pt * int(img['scale'].rstrip('x')))
        if px not in cache:
            cache[px] = full_square(px).convert('RGB')
        cache[px].save(f'{ios}/{fn}', optimize=True)
web = f'{REPO}/web/icons'
if os.path.isdir(web):
    for n, s, frac in [('Icon-192.png', 192, 0.40), ('Icon-512.png', 512, 0.40),
                       ('Icon-maskable-192.png', 192, 0.31), ('Icon-maskable-512.png', 512, 0.31)]:
        full_square(s, frac).save(f'{web}/{n}', optimize=True)
    fav = f'{REPO}/web/favicon.png'
    if os.path.exists(fav):
        full_square(Image.open(fav).size[0], 0.44).save(fav, optimize=True)
print('ok', far, mw, mh)
