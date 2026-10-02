# 앱 아이콘 원본 만들기 (직접 그린 도형 — 이미지·이모지 저작권 걱정 없음)
# 실행 (mortgage_app/ 에서): python3 tool_icon.py → flutter/assets/icon/icon-1024.png (알파 없음, App Store 규격)
from PIL import Image, ImageDraw

S = 4096  # 4배로 그린 뒤 줄여서 가장자리를 매끈하게
img = Image.new('RGB', (S, S))
top, bot = (20, 150, 118), (8, 88, 70)
# 위가 밝고 아래가 짙은 세로 그라디언트
grad = Image.linear_gradient('L').resize((S, S))
c1 = Image.new('RGB', (S, S), top)
c2 = Image.new('RGB', (S, S), bot)
img = Image.composite(c2, c1, grad)
d = ImageDraw.Draw(img)
W = (255, 255, 255)
u = S / 1024
# 집: 지붕 + 몸통
roof = [(512 * u, 210 * u), (850 * u, 500 * u), (174 * u, 500 * u)]
d.polygon(roof, fill=W)
d.rounded_rectangle([250 * u, 470 * u, 774 * u, 820 * u], radius=40 * u, fill=W)
# 몸통 안: 줄어드는 막대 3개 (갚아 나가는 잔액)
g = (12, 122, 96)
bars = [(318, 560), (448, 640), (578, 720)]
for x, ytop in bars:
    d.rounded_rectangle([x * u, ytop * u, (x + 110) * u, 770 * u], radius=18 * u, fill=g)
img = img.resize((1024, 1024), Image.LANCZOS)
img.save('flutter/assets/icon/icon-1024.png')
print('ok')
