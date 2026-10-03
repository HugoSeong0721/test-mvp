#!/usr/bin/env python3
"""카운티별 재산세 실효세율 — 미국 인구조사국 ACS 5년 추정치로 계산 (Tax Foundation 카운티 표와 같은 방식).

  실효세율(%) = 자가 주택 재산세 중앙값(B25103_001E) ÷ 주택 가치 중앙값(B25077_001E) × 100

개발 환경에서 api.census.gov 가 막혀 있어 Actions(`Fetch Census county property tax`)에서 돌린다.
결과: tools/mortgage/county_rates.json  → 앱 lib/core/counties.dart 로 변환
"""
import json
import sys
import time
import urllib.request

FIPS = {
    '01': 'AL', '02': 'AK', '04': 'AZ', '05': 'AR', '06': 'CA', '08': 'CO', '09': 'CT', '10': 'DE',
    '11': 'DC', '12': 'FL', '13': 'GA', '15': 'HI', '16': 'ID', '17': 'IL', '18': 'IN', '19': 'IA',
    '20': 'KS', '21': 'KY', '22': 'LA', '23': 'ME', '24': 'MD', '25': 'MA', '26': 'MI', '27': 'MN',
    '28': 'MS', '29': 'MO', '30': 'MT', '31': 'NE', '32': 'NV', '33': 'NH', '34': 'NJ', '35': 'NM',
    '36': 'NY', '37': 'NC', '38': 'ND', '39': 'OH', '40': 'OK', '41': 'OR', '42': 'PA', '44': 'RI',
    '45': 'SC', '46': 'SD', '47': 'TN', '48': 'TX', '49': 'UT', '50': 'VT', '51': 'VA', '53': 'WA',
    '54': 'WV', '55': 'WI', '56': 'WY',
}


def get(url):
    for k in range(4):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001
            print('retry', k, e, file=sys.stderr)
            time.sleep(5 * (k + 1))
    raise SystemExit('Census API failed: ' + url)


def main():
    data = year = None
    for y in (2024, 2023, 2022):
        url = (f'https://api.census.gov/data/{y}/acs/acs5'
               '?get=NAME,B25103_001E,B25077_001E&for=county:*&in=state:*')
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'soulfulfill-mortgage-data/1.0'})
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read().decode('utf-8', 'replace')
            data, year = json.loads(raw), y
            break
        except Exception as e:  # noqa: BLE001
            print('year', y, 'not available:', e)
            print('  response head:', (locals().get('raw') or '')[:400].replace('\n', ' '))
    if data is None:
        raise SystemExit('no ACS year available')
    head, rows = data[0], data[1:]
    ix = {h: i for i, h in enumerate(head)}
    out, skipped = {}, 0
    for r in rows:
        st = FIPS.get(r[ix['state']])
        if not st:
            continue  # 푸에르토리코 등
        try:
            tax, val = float(r[ix['B25103_001E']]), float(r[ix['B25077_001E']])
        except (TypeError, ValueError):
            skipped += 1
            continue
        # 음수 = 인구조사국의 '값 없음' 코드, 상단 캡 값(10,001 이상 등)도 그대로 쓴다
        if tax <= 0 or val <= 0:
            skipped += 1
            continue
        name = r[ix['NAME']].split(',')[0]
        out.setdefault(st, []).append([name, round(tax / val * 100, 2), int(tax), int(val)])
    for st in out:
        out[st].sort(key=lambda x: x[0])
    total = sum(len(v) for v in out.values())
    doc = {
        'source': f'U.S. Census Bureau, American Community Survey {year} 5-year estimates, '
                  'B25103_001E (median real estate taxes paid) / B25077_001E (median home value), by county',
        'year': year,
        'fields': ['county', 'effectiveRatePct', 'medianTax', 'medianValue'],
        'counties': out,
    }
    with open('tools/mortgage/county_rates.json', 'w') as f:
        json.dump(doc, f, separators=(',', ':'))
    print(f'ACS {year}: {total} counties in {len(out)} states (+DC), skipped {skipped}')
    tx = {c[0]: c for c in out.get('TX', [])}
    print('sample', tx.get('Harris County'), tx.get('Travis County'), out.get('NJ', [])[:2])


if __name__ == '__main__':
    main()
