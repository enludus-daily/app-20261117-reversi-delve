#!/usr/bin/env python3
"""迷宮リバーシのアイコン（1024×1024・透過なし）：暗い石壁のアーチの奥で、月長石と黒曜石の宝石が光る。
使い方: python3 scripts/make-icon-gems.py
"""
from PIL import Image, ImageDraw, ImageFilter
import random

S = 1024
img = Image.new('RGB', (S, S), (17, 26, 22))
d = ImageDraw.Draw(img)
# 石壁の目地
for row, y in enumerate(range(0, S, 96)):
    d.line([(0, y), (S, y)], fill=(34, 48, 40), width=4)
    off = 0 if row % 2 == 0 else 100
    for x in range(off, S, 200):
        d.line([(x, y), (x, y + 96)], fill=(30, 42, 35), width=4)

def glow(center, radius, color, alpha):
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    cx, cy = center
    ld.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=color + (alpha,))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))

base = img.convert('RGBA')
base = Image.alpha_composite(base, glow((512, 560), 360, (233, 169, 75), 150))

def octagon(cx, cy, r):
    k = r * 2 * 0.29
    x0, y0, x1, y1 = cx - r, cy - r, cx + r, cy + r
    return [(x0 + k, y0), (x1 - k, y0), (x1, y0 + k), (x1, y1 - k), (x1 - k, y1), (x0 + k, y1), (x0, y1 - k), (x0, y0 + k)]

def gem(cx, cy, r, face, facet, rim, sheen):
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    # 影
    ld.polygon(octagon(cx + 10, cy + 26, r), fill=(0, 0, 0, 140))
    layer = layer.filter(ImageFilter.GaussianBlur(18))
    ld = ImageDraw.Draw(layer)
    outer = octagon(cx, cy, r)
    inner = octagon(cx, cy, r * 0.52)
    ld.polygon(outer, fill=face)
    # 下と右の面を暗く
    for i in range(8):
        a, b = outer[i], outer[(i + 1) % 8]
        c, e = inner[(i + 1) % 8], inner[i]
        shade = [1.0, 0.92, 0.8, 0.72, 0.68, 0.76, 0.9, 1.05][i]
        col = tuple(max(0, min(255, int(v * shade))) for v in facet)
        ld.polygon([a, b, c, e], fill=col)
    ld.polygon(inner, fill=face)
    for i in range(8):
        ld.line([outer[i], inner[i]], fill=rim, width=5)
    ld.polygon(outer, outline=rim, width=10)
    ld.polygon(inner, outline=rim, width=5)
    ld.ellipse([cx - r * 0.55, cy - r * 0.62, cx - r * 0.12, cy - r * 0.42], fill=sheen)
    return layer

base = Image.alpha_composite(base, gem(380, 600, 230, (36, 33, 47), (61, 55, 84), (13, 11, 19), (154, 143, 203, 120)))
base = Image.alpha_composite(base, gem(640, 470, 260, (238, 242, 249), (198, 211, 236), (129, 147, 186), (255, 255, 255, 220)))
# 金の火の粉
rng = random.Random(3)
sp = ImageDraw.Draw(base)
for _ in range(26):
    x, y = rng.randint(120, 900), rng.randint(140, 900)
    if (x - 640) ** 2 + (y - 470) ** 2 < 290 ** 2 or (x - 380) ** 2 + (y - 600) ** 2 < 260 ** 2:
        continue
    r = rng.randint(4, 10)
    sp.ellipse([x - r, y - r, x + r, y + r], fill=(246, 217, 162, rng.randint(90, 200)))
base.convert('RGB').save('App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png')
print('ok')
