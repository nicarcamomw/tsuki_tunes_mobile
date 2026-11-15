"""Makes the splash: Android's launch logo and its animated glow.

    python3 tool/splash/make_glow_frames.py

From assets/images/tsuki_mask.webp (the entrance's mask, transparent) it
writes, in android/app/src/main/res/drawable:

- splash_glow_00..09.webp: the mask on the night (#181B22), 1024 px,
  centred and MASK_HEIGHT_PX tall (small enough for Android 12's icon
  circle, 192 of its 288 dp, to keep the horns), with a crimson glow
  lighting up behind it, up to the glow LoadingScreen starts with (splashGlowRadius =
  93 dp of the 288 dp icon, alpha 0.20, linear falloff). splash_anim.xml
  plays them on Android 12+; launch_background.xml shows the last one on
  Android 7 to 11.

LoadingScreen.maskWidth must follow MASK_HEIGHT_PX: the mask's width on
the 288 dp icon (startup_test checks it).
"""
import os

import numpy as np
from PIL import Image

RES = 'android/app/src/main/res/drawable'
MASK = 'assets/images/tsuki_mask.webp'
SIZE = 1024
MASK_HEIGHT_PX = 552
FRAMES = 10
GLOW_ALPHA = 0.20
GLOW_RADIUS_PX = 331  # 93 dp of the 288 dp icon
NIGHT = (24, 27, 34)  # AppColors.splash
CRIMSON = (255, 25, 25)  # AppColors.accent


def main():
    mask = Image.open(MASK).convert('RGBA')
    mw = round(mask.width * MASK_HEIGHT_PX / mask.height)
    m = mask.resize((mw, MASK_HEIGHT_PX), Image.LANCZOS)
    ox, oy = (SIZE - mw) // 2, (SIZE - MASK_HEIGHT_PX) // 2
    print(f'mask on the icon: {mw}x{MASK_HEIGHT_PX} px = {mw * 288 / SIZE:.2f} x {MASK_HEIGHT_PX * 288 / SIZE:.2f} dp')

    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    falloff = np.clip(1 - np.hypot(xx - SIZE / 2, yy - SIZE / 2) / GLOW_RADIUS_PX, 0, 1)
    night, crimson = np.array(NIGHT, float), np.array(CRIMSON, float)

    def frame(glow):
        a = falloff * glow
        img = night * (1 - a[..., None]) + crimson * a[..., None]
        out = Image.fromarray(img.astype('uint8'), 'RGB').convert('RGBA')
        out.alpha_composite(m, (ox, oy))
        return out.convert('RGB')

    for i in range(FRAMES):
        t = (i + 1) / FRAMES
        out = f'{RES}/splash_glow_{i:02d}.webp'
        frame(GLOW_ALPHA * (1 - (1 - t) ** 3)).save(out, 'WEBP', quality=88, method=6)
        print(out, os.path.getsize(out) // 1024, 'KB')


if __name__ == '__main__':
    main()
