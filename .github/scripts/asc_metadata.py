#!/usr/bin/env python3
"""App Store Connect 등록 정보를 API 로 채운다 (편집 가능한 iOS 버전 대상).

  asc_metadata.py <metadata.json> <screenshots_dir> <build_number|latest>

넣는 것: 부제·개인정보처리방침 URL(App Info), 설명·키워드·홍보 문구·지원 URL(버전 현지화),
스크린샷(기존 것은 지우고 json 순서대로), 빌드 연결, 심사 메모.
못 넣는 것(API 미제공 또는 사람이 정할 값): App Privacy 설문, 심사 연락처, 저작권, 제출 버튼.
환경변수 KEY_ID, ISSUER_ID, KEY_PATH 필요.
"""
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

API = 'https://api.appstoreconnect.apple.com/v1'


class ApiError(Exception):
    pass


def token():
    with open(os.environ['KEY_PATH']) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {'iss': os.environ['ISSUER_ID'], 'iat': now, 'exp': now + 1100, 'aud': 'appstoreconnect-v1'},
        key, algorithm='ES256', headers={'kid': os.environ['KEY_ID'], 'typ': 'JWT'})


def call(method, path, body=None):
    url = path if path.startswith('http') else API + path
    req = urllib.request.Request(
        url, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': f'Bearer {token()}', 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise ApiError(f'{method} {path} → HTTP {e.code}\n{e.read().decode(errors="replace")}')


def step(name, fn):
    try:
        fn()
        print(f'✓ {name}')
        return True
    except ApiError as e:
        print(f'✗ {name}\n{e}')
        return False


def main(meta_path, shots_dir, build_no):
    m = json.load(open(meta_path, encoding='utf-8'))
    loc = m['locale']

    app = call('GET', f'/apps?filter[bundleId]={m["bundleId"]}')['data'][0]
    app_id = app['id']
    versions = call('GET', f'/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10')['data']
    editable = {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED',
                'INVALID_BINARY', 'DEVELOPER_ACTION_NEEDED'}
    ver = next(v for v in versions if v['attributes']['appStoreState'] in editable)
    vid = ver['id']
    print(f'앱 {app["attributes"]["name"]} / 버전 {ver["attributes"]["versionString"]} ({ver["attributes"]["appStoreState"]})')
    ok = True

    def app_info():
        infos = call('GET', f'/apps/{app_id}/appInfos')['data']
        info = next(i for i in infos if i['attributes'].get('appStoreState') in editable | {None}) if len(infos) > 1 else infos[0]
        locs = call('GET', f'/appInfos/{info["id"]}/appInfoLocalizations')['data']
        l = next(x for x in locs if x['attributes']['locale'] == loc)
        call('PATCH', f'/appInfoLocalizations/{l["id"]}', {'data': {
            'type': 'appInfoLocalizations', 'id': l['id'],
            'attributes': {'subtitle': m['subtitle'], 'privacyPolicyUrl': m['privacyPolicyUrl']}}})
    ok &= step('부제·개인정보처리방침 URL', app_info)

    vlocs = call('GET', f'/appStoreVersions/{vid}/appStoreVersionLocalizations')['data']
    vloc = next(x for x in vlocs if x['attributes']['locale'] == loc)

    def version_text():
        call('PATCH', f'/appStoreVersionLocalizations/{vloc["id"]}', {'data': {
            'type': 'appStoreVersionLocalizations', 'id': vloc['id'],
            'attributes': {k: m[k] for k in ('description', 'keywords', 'promotionalText', 'supportUrl')}}})
    ok &= step('설명·키워드·홍보 문구·지원 URL', version_text)

    def screenshots():
        dtype = m['screenshotDisplayType']
        sets = call('GET', f'/appStoreVersionLocalizations/{vloc["id"]}/appScreenshotSets')['data']
        sset = next((s for s in sets if s['attributes']['screenshotDisplayType'] == dtype), None)
        if sset is None:
            sset = call('POST', '/appScreenshotSets', {'data': {
                'type': 'appScreenshotSets', 'attributes': {'screenshotDisplayType': dtype},
                'relationships': {'appStoreVersionLocalization': {
                    'data': {'type': 'appStoreVersionLocalizations', 'id': vloc['id']}}}}})['data']
        for old in call('GET', f'/appScreenshotSets/{sset["id"]}/appScreenshots')['data']:
            call('DELETE', f'/appScreenshots/{old["id"]}')
        ids = []
        for name in m['screenshots']:
            path = os.path.join(shots_dir, name)
            blob = open(path, 'rb').read()
            shot = call('POST', '/appScreenshots', {'data': {
                'type': 'appScreenshots', 'attributes': {'fileName': name, 'fileSize': len(blob)},
                'relationships': {'appScreenshotSet': {'data': {'type': 'appScreenshotSets', 'id': sset['id']}}}}})['data']
            for op in shot['attributes']['uploadOperations']:
                part = blob[op['offset']:op['offset'] + op['length']]
                req = urllib.request.Request(op['url'], data=part, method=op['method'],
                                             headers={h['name']: h['value'] for h in op['requestHeaders']})
                urllib.request.urlopen(req, timeout=120).read()
            call('PATCH', f'/appScreenshots/{shot["id"]}', {'data': {
                'type': 'appScreenshots', 'id': shot['id'],
                'attributes': {'uploaded': True, 'sourceFileChecksum': hashlib.md5(blob).hexdigest()}}})
            ids.append(shot['id'])
            print(f'  업로드 {name}')
        call('PATCH', f'/appScreenshotSets/{sset["id"]}/relationships/appScreenshots',
             {'data': [{'type': 'appScreenshots', 'id': i} for i in ids]})
    ok &= step(f'스크린샷 {len(m["screenshots"])}장 ({m["screenshotDisplayType"]})', screenshots)

    def build():
        q = f'/builds?filter[app]={app_id}&filter[preReleaseVersion.version]={ver["attributes"]["versionString"]}&sort=-uploadedDate&limit=20'
        builds = call('GET', q)['data']
        valid = [b for b in builds if b['attributes']['processingState'] == 'VALID']
        b = valid[0] if build_no == 'latest' else next(x for x in valid if x['attributes']['version'] == build_no)
        call('PATCH', f'/appStoreVersions/{vid}/relationships/build', {'data': {'type': 'builds', 'id': b['id']}})
        print(f'  빌드 {b["attributes"]["version"]} 연결')
    ok &= step('빌드 연결', build)

    def review():
        attrs = {'notes': m['reviewNotes'], 'demoAccountRequired': False}
        try:
            d = call('GET', f'/appStoreVersions/{vid}/appStoreReviewDetail')['data']
        except ApiError:
            d = None
        if d:
            call('PATCH', f'/appStoreReviewDetails/{d["id"]}', {'data': {
                'type': 'appStoreReviewDetails', 'id': d['id'], 'attributes': attrs}})
        else:
            call('POST', '/appStoreReviewDetails', {'data': {
                'type': 'appStoreReviewDetails', 'attributes': attrs,
                'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}})
    ok &= step('심사 메모', review)

    if not ok:
        sys.exit(1)


if __name__ == '__main__':
    main(*sys.argv[1:4])
