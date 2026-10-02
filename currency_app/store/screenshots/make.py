#!/usr/bin/env python3
"""App Store 스크린샷 생성: raw/ 의 아이폰 원본 → 6.7형(1290×2796) 홍보 이미지.

  python3 currency_app/store/screenshots/make.py

원본 위쪽 상태바(시계·TestFlight 표시)는 잘라내고, 위에 제목/부제를 얹는다.
글꼴은 fonts/ 의 Inter (SIL Open Font License).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
W, H = 1290, 2796
BG = (14, 17, 22)
GOLD = (232, 180, 76)
TEXT = (232, 235, 239)
SUB = (154, 164, 178)
LINE = (36, 44, 54)

SHOTS = [
    ('IMG_9557.png', '01-convert.png', 'Every currency\nat a glance', 'Dollars, euros, Bitcoin & gold — instantly.'),
    ('IMG_9545.png', '02-type-any-row.png', 'Type in any row', 'Edit any currency — the rest follow.'),
    ('IMG_9555.png', '03-gold-crypto.png', 'Gold, Bitcoin &\n20+ currencies', 'Search by name or code. Works offline.'),
    ('IMG_9543.png', '04-chart.png', 'Real rate history', '1W · 1M · 3M · 1Y with highs and lows.'),
]

STATUS_BAR = 175  # 원본(1170×2532) 기준 위쪽 상태바 높이


def font(name, size):
    return ImageFont.truetype(str(HERE / 'fonts' / name), size)


def background():
    img = Image.new('RGB', (W, H), BG)
    glow = Image.new('L', (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-300, -900, W + 300, 900), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    img.paste(Image.new('RGB', (W, H), GOLD), (0, 0), glow)
    return img


def rounded(im, r):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *im.size), r, fill=255)
    out = Image.new('RGBA', im.size)
    out.paste(im, (0, 0), mask)
    return out


def make(src, dst, title, sub):
    img = background()
    d = ImageDraw.Draw(img)
    tf, sf = font('Inter-ExtraBold.ttf', 112), font('Inter-Medium.ttf', 50)
    y = 170
    for line in title.split('\n'):
        w = d.textlength(line, font=tf)
        d.text(((W - w) / 2, y), line, font=tf, fill=TEXT)
        y += 132
    w = d.textlength(sub, font=sf)
    d.text(((W - w) / 2, y + 24), sub, font=sf, fill=SUB)

    shot = Image.open(HERE / 'raw' / src).convert('RGB')
    shot = shot.crop((0, STATUS_BAR, shot.width, shot.height))
    sw = 1060
    sh = round(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    top = H - sh - 60
    x = (W - sw) // 2
    border = Image.new('RGB', (sw + 8, sh + 8), LINE)
    img.paste(rounded(border, 64), (x - 4, top - 4), rounded(border, 64))
    r = rounded(shot, 60)
    img.paste(r, (x, top), r)
    img.save(HERE / dst, optimize=True)
    print(dst, img.size, 'screenshot top', top)


if __name__ == '__main__':
    for args in SHOTS:
        make(*args)
