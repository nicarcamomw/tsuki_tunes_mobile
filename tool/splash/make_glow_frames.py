"""Makes Android 12+'s animated splash: the mask's red glow lighting up.

    python3 tool/splash/make_glow_frames.py

Reads android/app/src/main/res/drawable/splash_logo.png (the static splash)
and assets/images/cyber_oni_mask.png (the same mask, transparent), and
writes splash_glow_00..09.webp next to splash_logo: the logo with a radial
crimson glow behind the mask, from nothing to the glow LoadingScreen starts
with (LoadingScreen.splashGlowRadius = 93 dp of the 288 dp icon, alpha
0.20, linear falloff). splash_anim.xml plays them; launch_background.xml
shows the last one on Android 7 to 11.
"""
import os

import numpy as np
from PIL import Image

RES = 'android/app/src/main/res'
FRAMES = 10
GLOW_ALPHA = 0.20
GLOW_RADIUS_PX = 331  # 93 dp of the 288 dp icon, on the 1024 px image
NIGHT = (24, 27, 34)  # AppColors.splash, #181B22
CRIMSON = (255, 25, 25)  # AppColors.accent


def bbox(mask_bool):
    ys, xs = np.where(mask_bool)
    return xs.min(), xs.max(), ys.min(), ys.max()


def main():
    splash = Image.open(f'{RES}/drawable/splash_logo.png').convert('RGB')
    mask = Image.open('assets/images/cyber_oni_mask.png').convert('RGBA')
    sp = np.array(splash).astype(int)
    sx0, sx1, sy0, sy1 = bbox(np.abs(sp - np.array(NIGHT)).sum(axis=2) > 30)
    mx0, mx1, my0, my1 = bbox(np.array(mask)[:, :, 3] > 40)
    # The transparent mask scaled and placed on the splash's own.
    k = ((sx1 - sx0) / (mx1 - mx0) + (sy1 - sy0) / (my1 - my0)) / 2
    m = mask.resize((round(mask.width * k), round(mask.height * k)), Image.LANCZOS)
    ox, oy = round(sx0 - mx0 * k), round(sy0 - my0 * k)

    w = splash.width
    yy, xx = np.mgrid[0:w, 0:w]
    d = np.hypot(xx - (sx0 + sx1) / 2, yy - (sy0 + sy1) / 2)
    falloff = np.clip(1 - d / GLOW_RADIUS_PX, 0, 1)
    night, crimson = np.array(NIGHT, float), np.array(CRIMSON, float)

    for i in range(FRAMES):
        t = (i + 1) / FRAMES
        a = falloff * GLOW_ALPHA * (1 - (1 - t) ** 3)  # ease out
        img = night * (1 - a[..., None]) + crimson * a[..., None]
        frame = Image.fromarray(img.astype('uint8'), 'RGB').convert('RGBA')
        frame.alpha_composite(m, (ox, oy))
        out = f'{RES}/drawable/splash_glow_{i:02d}.webp'
        frame.convert('RGB').save(out, 'WEBP', quality=88, method=6)
        print(out, os.path.getsize(out) // 1024, 'KB')


if __name__ == '__main__':
    main()
