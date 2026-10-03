#!/usr/bin/env python3
"""앱 내 구입(IAP) 상품을 App Store Connect API 로 만든다 — 없을 때만 만들고, 있으면 빠진 것만 채운다.

  asc_iap.py <iap.json> <review_screenshot.png>

iap.json 예 (catdoku_app/store/iap.json):
  {"bundleId": "...", "productId": "...", "referenceName": "...", "type": "NON_CONSUMABLE",
   "priceUSD": "1.99", "reviewNote": "...", "locales": {"en-US": {"name": "...", "description": "..."}}}

사람이 해야 하는 것(API 없음): App Store Connect → 비즈니스 → 유료 앱 계약(은행·세금). 이게 없으면 상품은
만들어져도 팔 수 없고 TestFlight 샌드박스 결제도 안 된다. 첫 IAP 는 앱 새 버전과 함께 심사에 낸다.
환경변수 KEY_ID, ISSUER_ID, KEY_PATH 필요.
"""
import hashlib
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from asc_metadata import ApiError, call, step  # noqa: E402

V2 = 'https://api.appstoreconnect.apple.com/v2'


def all_pages(url):
    out = []
    while url:
        r = call('GET', url)
        out += r['data']
        url = r.get('links', {}).get('next')
    return out


def main(cfg_path, shot_path):
    cfg = json.load(open(cfg_path))
    app = call('GET', f'/apps?filter[bundleId]={cfg["bundleId"]}')['data']
    if not app:
        sys.exit(f'앱 레코드 없음: {cfg["bundleId"]}')
    app_id = app[0]['id']
    print(f'앱: {app[0]["attributes"]["name"]} ({app_id})')

    found = [p for p in all_pages(f'/apps/{app_id}/inAppPurchasesV2?limit=200')
             if p['attributes']['productId'] == cfg['productId']]
    if found:
        iap = found[0]
        print(f'상품 있음: {cfg["productId"]} (상태 {iap["attributes"].get("state")})')
    else:
        iap = call('POST', f'{V2}/inAppPurchases', {'data': {
            'type': 'inAppPurchases',
            'attributes': {'name': cfg['referenceName'], 'productId': cfg['productId'],
                           'inAppPurchaseType': cfg['type'], 'reviewNote': cfg.get('reviewNote', '')},
            'relationships': {'app': {'data': {'type': 'apps', 'id': app_id}}}}})['data']
        print(f'✓ 상품 만듦: {cfg["productId"]}')
    iap_id = iap['id']
    ok = True

    def locales():
        have = {l['attributes']['locale']: l for l in
                call('GET', f'{V2}/inAppPurchases/{iap_id}/inAppPurchaseLocalizations')['data']}
        for loc, v in cfg['locales'].items():
            if loc in have:
                call('PATCH', f'/inAppPurchaseLocalizations/{have[loc]["id"]}', {'data': {
                    'type': 'inAppPurchaseLocalizations', 'id': have[loc]['id'],
                    'attributes': {'name': v['name'], 'description': v['description']}}})
            else:
                call('POST', '/inAppPurchaseLocalizations', {'data': {
                    'type': 'inAppPurchaseLocalizations',
                    'attributes': {'locale': loc, 'name': v['name'], 'description': v['description']},
                    'relationships': {'inAppPurchaseV2': {'data': {'type': 'inAppPurchases', 'id': iap_id}}}}})
    ok &= step('표시 이름·설명', locales)

    def price():
        points = all_pages(f'{V2}/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200')
        pp = next((p for p in points if p['attributes']['customerPrice'] == cfg['priceUSD']), None)
        if not pp:
            raise ApiError(f'USD {cfg["priceUSD"]} 가격 단계를 못 찾음')
        call('POST', '/inAppPurchasePriceSchedules', {
            'data': {'type': 'inAppPurchasePriceSchedules', 'relationships': {
                'inAppPurchase': {'data': {'type': 'inAppPurchases', 'id': iap_id}},
                'baseTerritory': {'data': {'type': 'territories', 'id': 'USA'}},
                'manualPrices': {'data': [{'type': 'inAppPurchasePrices', 'id': '${p1}'}]}}},
            'included': [{'type': 'inAppPurchasePrices', 'id': '${p1}',
                          'attributes': {'startDate': None},
                          'relationships': {'inAppPurchasePricePoint': {
                              'data': {'type': 'inAppPurchasePricePoints', 'id': pp['id']}}}}]})
    ok &= step(f'가격 USD {cfg["priceUSD"]} (다른 나라는 Apple 자동 환산)', price)

    def availability():
        terr = all_pages('/territories?limit=200')
        call('POST', '/inAppPurchaseAvailabilities', {'data': {
            'type': 'inAppPurchaseAvailabilities',
            'attributes': {'availableInNewTerritories': True},
            'relationships': {
                'inAppPurchase': {'data': {'type': 'inAppPurchases', 'id': iap_id}},
                'availableTerritories': {'data': [{'type': 'territories', 'id': t['id']} for t in terr]}}}})
    ok &= step('판매 국가 (앱이 나가는 모든 나라)', availability)

    def screenshot():
        blob = open(shot_path, 'rb').read()
        name = os.path.basename(shot_path)
        r = call('POST', '/inAppPurchaseAppStoreReviewScreenshots', {'data': {
            'type': 'inAppPurchaseAppStoreReviewScreenshots',
            'attributes': {'fileName': name, 'fileSize': len(blob)},
            'relationships': {'inAppPurchaseV2': {'data': {'type': 'inAppPurchases', 'id': iap_id}}}}})['data']
        for op in r['attributes']['uploadOperations']:
            part = blob[op['offset']:op['offset'] + op['length']]
            req = urllib.request.Request(op['url'], data=part, method=op['method'],
                                         headers={h['name']: h['value'] for h in op['requestHeaders']})
            urllib.request.urlopen(req, timeout=120).read()
        call('PATCH', f'/inAppPurchaseAppStoreReviewScreenshots/{r["id"]}', {'data': {
            'type': 'inAppPurchaseAppStoreReviewScreenshots', 'id': r['id'],
            'attributes': {'uploaded': True, 'sourceFileChecksum': hashlib.md5(blob).hexdigest()}}})
    ok &= step('심사용 스크린샷', screenshot)

    state = call('GET', f'{V2}/inAppPurchases/{iap_id}')['data']['attributes'].get('state')
    print(f'상품 상태: {state}  (READY_TO_SUBMIT 이면 다음 앱 버전과 함께 심사에 낼 수 있다)')
    if not ok:
        sys.exit(1)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
