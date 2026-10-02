# 앱 아이콘 원본 만들기 (직접 그린 도형 — 이미지·이모지 저작권 걱정 없음)
# 실행 (fuellog_app/ 에서): python3 tool_icon.py → flutter/assets/icon/icon-1024.png (알파 없음, App Store 규격)
# 모양: 파란 바탕 + 흰 연료 방울 + 방울 안의 연비 게이지(바늘이 '좋음' 쪽)
import math
from PIL import Image, ImageDraw

S = 4096  # 4배로 그린 뒤 줄여서 가장자리를 매끈하게
u = S / 1024
top, bot = (40, 128, 240), (14, 76, 180)
grad = Image.linear_gradient('L').resize((S, S))
img = Image.composite(Image.new('RGB', (S, S), bot), Image.new('RGB', (S, S), top), grad)
d = ImageDraw.Draw(img)
W = (255, 255, 255)
B = (22, 101, 216)

# 연료 방울: 아래 원 + 위로 뾰족한 삼각형
cx, cy, r = 512, 590, 270
d.ellipse([(cx - r) * u, (cy - r) * u, (cx + r) * u, (cy + r) * u], fill=W)
tip = 150
# 원에 접하는 두 점까지 삼각형
ang = math.asin(r / (cy - tip))
t1 = (cx - r * math.cos(ang), cy - r * math.sin(ang))
t2 = (cx + r * math.cos(ang), cy - r * math.sin(ang))
d.polygon([(cx * u, tip * u), (t1[0] * u, t1[1] * u), (t2[0] * u, t2[1] * u)], fill=W)

# 게이지 호 (왼쪽 아래 → 위 → 오른쪽 아래)
gr, gw, gy = 170, 46, 630
box = [(cx - gr) * u, (gy - gr) * u, (cx + gr) * u, (gy + gr) * u]
d.arc(box, start=150, end=390, fill=B, width=int(gw * u))
# 눈금 끝 둥글게
for deg in (150, 390):
    rad = math.radians(deg)
    rr = gw / 2 - 1
    # 호 두께의 가운데에 원
    xm, ym = cx + (gr - gw / 2) * math.cos(rad), gy + (gr - gw / 2) * math.sin(rad)
    d.ellipse([(xm - rr) * u, (ym - rr) * u, (xm + rr) * u, (ym + rr) * u], fill=B)
# 바늘: 오른쪽 위(좋은 연비)
na = math.radians(-50)
nl = 125
hx, hy = cx, gy
d.line([(hx * u, hy * u), ((hx + nl * math.cos(na)) * u, (hy + nl * math.sin(na)) * u)], fill=B, width=int(30 * u))
d.ellipse([(hx - 38) * u, (hy - 38) * u, (hx + 38) * u, (hy + 38) * u], fill=B)
ex, ey = hx + nl * math.cos(na), hy + nl * math.sin(na)
d.ellipse([(ex - 15) * u, (ey - 15) * u, (ex + 15) * u, (ey + 15) * u], fill=B)

img = img.resize((1024, 1024), Image.LANCZOS)
img.save('flutter/assets/icon/icon-1024.png')
print('ok')
