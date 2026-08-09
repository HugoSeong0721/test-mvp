#!/usr/bin/env python3
"""출시용 빌드(currency-app-v1.html)를 프로토타입에서 생성한다.

두 빌드가 손으로 고치다 어긋나는 것을 막기 위해, 앱 본체는 항상
currency-app-preview.html 하나만 고치고 이 스크립트로 v1을 다시 만든다.

  python3 currency_app/build-v1.py

v1과 프로토타입의 차이는 딱 세 가지:
  1) localStorage 키 분리 — 두 링크의 설정이 섞이지 않게
  2) 타이틀
  3) 첫 실행 온보딩(onboarding-v1.html)을 뒤에 붙임
"""
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
SRC = HERE / 'currency-app-preview.html'
FRAGMENT = HERE / 'onboarding-v1.html'
OUT = HERE / 'currency-app-v1.html'
DOCS = HERE.parent / 'docs'

REPLACEMENTS = [
    ("'fx-proto-v3'", "'fx-app-v1'", 2),
    ('<title>환율 · Currency</title>', '<title>솜 환율 · Som Currency</title>', 1),
]


def build() -> str:
    html = SRC.read_text(encoding='utf-8')
    for old, new, count in REPLACEMENTS:
        found = html.count(old)
        if found != count:
            sys.exit(f'build-v1: {old!r} 를 {count}번 기대했지만 {found}번 발견했습니다. '
                     f'프로토타입 쪽이 바뀌었는지 확인하세요.')
        html = html.replace(old, new)
    return html.rstrip('\n') + '\n\n' + FRAGMENT.read_text(encoding='utf-8')


def main() -> None:
    out = build()
    OUT.write_text(out, encoding='utf-8')
    # GitHub Pages 배포용 사본까지 함께 갱신
    (DOCS / 'currency-app-v1.html').write_text(out, encoding='utf-8')
    (DOCS / 'currency-app.html').write_text(SRC.read_text(encoding='utf-8'), encoding='utf-8')
    print(f'built {OUT.name} + docs/ 사본 2개')


if __name__ == '__main__':
    main()
