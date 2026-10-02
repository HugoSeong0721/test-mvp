#!/usr/bin/env python3
"""App Store 배포 서명 준비/정리 (App Store Connect API).

  asc_signing.py setup   <bundle_id> <workdir>   → 키·CSR 생성, 배포 인증서·App Store 프로파일 발급
  asc_signing.py cleanup <workdir>               → 이번 실행에서 만든 프로파일·인증서 삭제

기기 등록 없이 App Store 배포 서명을 하기 위한 것. 인증서 개수 제한(계정당 수 개)이 있어서
실행마다 새로 만들고 끝나면 반드시 지운다. 환경변수 KEY_ID, ISSUER_ID, KEY_PATH 필요.
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

import jwt  # PyJWT

API = 'https://api.appstoreconnect.apple.com/v1'
OPENSSL = '/usr/bin/openssl'  # macOS LibreSSL — p12 를 security import 가 읽는 형식으로 만든다


def token():
    with open(os.environ['KEY_PATH']) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {'iss': os.environ['ISSUER_ID'], 'iat': now, 'exp': now + 1100, 'aud': 'appstoreconnect-v1'},
        key, algorithm='ES256', headers={'kid': os.environ['KEY_ID'], 'typ': 'JWT'})


def call(method, path, body=None):
    req = urllib.request.Request(
        API + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': f'Bearer {token()}', 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.exit(f'{method} {path} → HTTP {e.code}\n{e.read().decode(errors="replace")}')


def sh(*args):
    subprocess.run(args, check=True)


def setup(bundle_id, wd):
    os.makedirs(wd, exist_ok=True)
    key, csr = f'{wd}/dist.key', f'{wd}/dist.csr'
    sh(OPENSSL, 'genrsa', '-out', key, '2048')
    sh(OPENSSL, 'req', '-new', '-key', key, '-out', csr, '-subj', '/CN=GitHub CI/C=US')
    with open(csr) as f:
        csr_pem = f.read()

    cert = call('POST', '/certificates', {'data': {'type': 'certificates', 'attributes': {
        'certificateType': 'DISTRIBUTION', 'csrContent': csr_pem}}})['data']
    state = {'certificate_id': cert['id']}
    with open(f'{wd}/state.json', 'w') as f:
        json.dump(state, f)
    with open(f'{wd}/dist.cer', 'wb') as f:
        f.write(base64.b64decode(cert['attributes']['certificateContent']))
    sh(OPENSSL, 'x509', '-inform', 'der', '-in', f'{wd}/dist.cer', '-out', f'{wd}/dist.pem')
    sh(OPENSSL, 'pkcs12', '-export', '-inkey', key, '-in', f'{wd}/dist.pem',
       '-out', f'{wd}/dist.p12', '-passout', 'pass:ci')

    found = call('GET', f'/bundleIds?filter[identifier]={bundle_id}&limit=50')['data']
    bid = next((b['id'] for b in found if b['attributes']['identifier'] == bundle_id), None)
    if not bid:
        sys.exit(f'번들 ID {bundle_id} 가 developer.apple.com 에 등록되어 있지 않습니다.')

    name = f'ci-appstore-{os.environ.get("GITHUB_RUN_ID", int(time.time()))}'
    prof = call('POST', '/profiles', {'data': {
        'type': 'profiles',
        'attributes': {'name': name, 'profileType': 'IOS_APP_STORE'},
        'relationships': {
            'bundleId': {'data': {'type': 'bundleIds', 'id': bid}},
            'certificates': {'data': [{'type': 'certificates', 'id': cert['id']}]},
        }}})['data']
    state.update(profile_id=prof['id'], profile_name=name, profile_uuid=prof['attributes']['uuid'])
    with open(f'{wd}/state.json', 'w') as f:
        json.dump(state, f)
    with open(f'{wd}/profile.mobileprovision', 'wb') as f:
        f.write(base64.b64decode(prof['attributes']['profileContent']))
    print(json.dumps({k: v for k, v in state.items() if k != 'certificate_id'}))


def cleanup(wd):
    try:
        with open(f'{wd}/state.json') as f:
            state = json.load(f)
    except FileNotFoundError:
        print('정리할 것 없음')
        return
    if state.get('profile_id'):
        call('DELETE', f'/profiles/{state["profile_id"]}')
        print('프로파일 삭제')
    if state.get('certificate_id'):
        call('DELETE', f'/certificates/{state["certificate_id"]}')
        print('인증서 삭제')


if __name__ == '__main__':
    if sys.argv[1] == 'setup':
        setup(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'cleanup':
        cleanup(sys.argv[2])
    else:
        sys.exit('usage: asc_signing.py setup <bundle_id> <workdir> | cleanup <workdir>')
