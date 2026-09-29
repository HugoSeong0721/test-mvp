# 솜 환율 — 안드로이드 앱 (Flutter)

웹 프로토타입(`currency_app/currency-app-v1.html`)을 그대로 옮긴 네이티브 앱.
Google Play에 올리는 건 **이 폴더에서 나온 AAB 파일**이다.

- 패키지 ID: `com.iottie.somrate` — **한 번 Play에 올리면 영구히 못 바꾼다.** 첫 업로드 전에 바꿀 거면
  `android/app/build.gradle.kts` 의 `applicationId`/`namespace`, `android/app/src/main/kotlin/…` 폴더 이름을 같이 바꾼다.
- 앱 이름(폰에 보이는): `android/app/src/main/AndroidManifest.xml` 의 `android:label`
- 버전: `pubspec.yaml` 의 `version: 1.0.0+1` — 스토어에 다시 올릴 때마다 `+N` 을 1 올린다.

## 폴더

```
lib/
  main.dart                       앱 진입, 탭(변환/차트), 온보딩 분기
  core/
    currencies.dart               통화 목록 + 오프라인 스냅샷 + 시간대
    rate_service.dart             실시간 환율 (API → 캐시 → 스냅샷)
    store.dart                    앱 상태(기준 통화·목록·입력 버퍼), 저장
    format.dart                   금액 표기 (스마트 정밀도)
    theme.dart                    색 토큰 (다크 기본 / 라이트)
    widgets.dart                  국기·변동률·현지시각·커서 등 공용 위젯
  features/
    converter/                    변환 화면, 키패드, 통화 선택 시트
    chart/                        기간별 차트
    onboarding/                   첫 실행 기준 통화 선택
assets/icon/                      앱 아이콘 원본 (1024px)
android/                          안드로이드 프로젝트 (flutter create 로 생성)
```

## 빌드는 GitHub Actions 가 한다

`main` 에 이 폴더 변경이 푸시되면 `.github/workflows/build-android.yml` 이 돌아
**AAB(Play 업로드용)** 와 **APK(폰에 직접 설치용)** 를 만든다.

내려받기: 저장소 → **Actions** → `Build Android (환율 앱)` → 최근 실행 → 맨 아래 **Artifacts**
→ `somrate-aab` / `somrate-apk` 다운로드 (zip 안에 파일이 있다).

수동으로 돌리려면 같은 화면에서 **Run workflow**.

### 서명 키 등록 (Play 업로드 전에 한 번만)

서명 Secrets 가 없으면 debug 키로 빌드되고, 그 AAB 는 Play 가 받지 않는다.
**키 파일은 잃어버리면 앱 업데이트를 영원히 못 하니 백업해 둔다** (Play App Signing 을 쓰면
업로드 키 분실 시 재설정은 가능하지만 번거롭다).

1. PC 에 JDK 가 있으면 터미널에서 (Android Studio 설치 시 같이 들어 있음):
   ```
   keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   비밀번호 2개(저장소·키)를 물어본다. 같은 걸 써도 된다. 이름/조직 질문은 아무거나.
2. 파일을 base64 문자열로 바꾼다.
   - Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard`
   - macOS: `base64 -i upload-keystore.jks | pbcopy`
   - Linux: `base64 -w0 upload-keystore.jks`
3. GitHub 저장소 → **Settings → Secrets and variables → Actions → New repository secret** 로 4개 등록:

   | 이름 | 값 |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | 2번에서 복사한 긴 문자열 |
   | `ANDROID_KEYSTORE_PASSWORD` | 저장소 비밀번호 |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | 키 비밀번호 |

4. Actions 에서 **Run workflow** → 이번 AAB 는 릴리스 키로 서명돼 Play 에 올릴 수 있다.

## Play Console 순서

1. **Create app** — 앱 이름 `솜 환율`(또는 원하는 이름), 기본 언어, App, 무료. 선언 체크 후 생성.
2. 왼쪽 **Test and release → Testing → Internal testing** 에서 먼저 올려 본다.
   **Create new release → Upload** 에 AAB 를 넣는다. (처음엔 Play App Signing 동의 화면이 나온다 — 동의.)
   테스터 이메일을 넣고 링크로 폰에 설치해 확인.
3. **Grow users → Store presence → Main store listing**
   - 앱 이름, 짧은 설명(80자), 자세한 설명(4000자)
   - 앱 아이콘 512×512 → `currency_app/store/icon-512.png`
   - 피처 그래픽 1024×500, 스크린샷 최소 2장 (폰에서 캡처)
4. **Monitor and improve → Policy and programs → App content** 에서 필수 항목 채우기
   - 개인정보처리방침 URL → `https://hugoseong0721.github.io/test-mvp/somrate-privacy.html`
   - 광고: 현재 **없음** (AdMob 붙이면 "예"로 바꾼다)
   - 데이터 안전(Data safety): 아래 초안 참고
   - 콘텐츠 등급 설문: 유틸리티, 폭력·도박 등 전부 아니오 → 전체이용가
   - 타겟 연령: 18세 이상 성인 대상으로 두는 게 심사가 단순
   - 뉴스 앱 아니오, COVID 앱 아니오, 정부 앱 아니오, 금융 기능: **환율 정보 제공만**, 거래·송금 없음
5. **Production → Create new release** 로 같은 AAB(또는 새 버전) 올리고 **Send for review**.

### 데이터 안전 설문 답변 초안

이 앱은 계정이 없고 개인정보를 서버로 보내지 않는다.

| 질문 | 답 |
|---|---|
| 사용자 데이터를 수집하거나 공유하나요? | **아니요** |
| 데이터가 전송 중 암호화되나요? | 예 (HTTPS 로 환율만 받아옴) |
| 데이터 삭제 요청 방법 제공? | 해당 없음 (수집 안 함) |

기준 통화·목록·마지막 환율은 **폰 안에만** 저장된다(`shared_preferences`). 서버 없음, 로그인 없음, 분석 SDK 없음.
AdMob 을 붙이는 순간 "광고 ID 수집"으로 답이 바뀌니 그때 다시 채운다.

### 개인 계정이면

2023-11-13 이후 만든 **개인** 개발자 계정은 프로덕션 전에 **비공개 테스트 12명 × 연속 14일**이 필수다.
회사(Organization) 계정은 면제. Developer account → Account details 에서 확인.

## 로컬에서 돌려보기 (Flutter 설치된 PC)

```
cd currency_app/flutter
flutter pub get
flutter run                     # 연결된 폰/에뮬레이터
flutter build appbundle         # build/app/outputs/bundle/release/app-release.aab
dart run flutter_launcher_icons  # assets/icon 을 바꿨을 때 아이콘 재생성
```
