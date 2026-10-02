# 한눈환율 — 안드로이드 앱 (Flutter)

웹 프로토타입(`currency_app/currency-app-v1.html`)을 그대로 옮긴 네이티브 앱.
Google Play에 올리는 건 **이 폴더에서 나온 AAB 파일**이다.

- 패키지 ID: `com.soulfulfill.currency` — **한 번 Play에 올리면 영구히 못 바꾼다.** 첫 업로드 전에 바꿀 거면
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

1. **Create app** — 앱 이름 `한눈환율`(또는 원하는 이름), 기본 언어, App, 무료. 선언 체크 후 생성.
2. 왼쪽 **Test and release → Testing → Internal testing** 에서 먼저 올려 본다.
   **Create new release → Upload** 에 AAB 를 넣는다. (처음엔 Play App Signing 동의 화면이 나온다 — 동의.)
   테스터 이메일을 넣고 링크로 폰에 설치해 확인.
3. **Grow users → Store presence → Main store listing**
   - 앱 이름, 짧은 설명(80자), 자세한 설명(4000자)
   - 앱 아이콘 512×512 → `currency_app/store/icon-512.png`
   - 피처 그래픽 1024×500, 스크린샷 최소 2장 (폰에서 캡처)
4. **Monitor and improve → Policy and programs → App content** 에서 필수 항목 채우기
   - 개인정보처리방침 URL → `https://hugoseong0721.github.io/test-mvp/somrate-privacy.html`
   - 광고: **예** (AdMob 배너 — 아래 "광고" 절)
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

## 광고 (AdMob)

탭바 바로 위 320×50 배너 하나 — `lib/core/ads.dart`.

| 플랫폼 | AdMob 앱 | 앱 ID | 배너 단위 ID |
|---|---|---|---|
| iOS | Currency Exchange (개인 AdMob 계정) | `ca-app-pub-4724352880074547~5579610172` (ios/Runner/Info.plist) | `ca-app-pub-4724352880074547/2514463130` |
| Android | **아직 미등록** — Google 테스트 ID 사용 중 | AndroidManifest.xml `APPLICATION_ID` | `ads.dart` |

안드로이드에 실제 광고를 내려면 AdMob 에서 Android 앱을 하나 더 만들고 위 두 곳의 테스트 ID 를 교체한다.
AdMob 콘솔의 "Payment setup incomplete" 는 수익이 생기기 전까지는 광고 송출을 막지 않지만,
**앱이 스토어에 올라간 뒤 AdMob 앱에 스토어 링크를 연결하고 결제 프로필을 채워야** 광고가 정상 송출된다.

## iOS (App Store)

번들 ID `com.soulfulfill.currency`, 표시 이름 `한눈환율`. 안드로이드와 같은 Dart 코드를 그대로 쓴다.

### CI 가 해 두는 것

`main` 에 이 폴더 변경이 푸시되면 `.github/workflows/build-ios.yml` 이 macOS 러너에서 돈다.
- `ios/` 가 없으면 `flutter create --platforms=ios` 로 만들고 AdMob 앱 ID·표시 이름·아이콘·
  `ITSAppUsesNonExemptEncryption=false` 를 채워 **main 에 커밋**한다 (처음 한 번).
- 서명 없이 릴리스 빌드가 통과하는지 확인한다. Actions 에 올라오는 `somrate-ios-unsigned` 는
  검증용일 뿐 폰에 설치할 수 없다.

### 맥 없이 올리기 — `release-ios.yml` (추천)

한 번만 준비:
1. **번들 ID 등록** — developer.apple.com/account → Certificates, IDs & Profiles → Identifiers → **+**
   → App IDs → App → Description `Currency Converter`, Bundle ID **Explicit** `com.soulfulfill.currency` → Continue → Register.
2. **앱 레코드 만들기** — appstoreconnect.apple.com → Apps → **+ → New App**
   → iOS, 이름 `한눈환율`, 기본 언어 Korean, 번들 ID `com.soulfulfill.currency`, SKU `somrate`, Full Access.
3. **API 키** — App Store Connect → Users and Access → **Integrations** → App Store Connect API
   → (처음이면 Request Access) → Team Keys **+** → 이름 `github-ci`, Access **Admin** → Generate
   → **Download API Key**(.p8, 한 번만 받을 수 있음). 같은 화면의 **Key ID**, 위쪽 **Issuer ID** 를 적어 둔다.
4. **Team ID** — developer.apple.com/account → Membership details → Team ID.
5. GitHub 저장소 → Settings → Secrets and variables → Actions → New repository secret 4개:
   `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`(.p8 파일을 메모장으로 열어 전체 복사).

올릴 때: Actions → **Release iOS** → Run workflow. 10~20분 뒤 App Store Connect → TestFlight 에
빌드가 뜨면(처리 10~30분) 버전 화면에서 그 빌드를 고르고 Submit for Review.

### 맥에서 App Store 에 올리기 (맥을 쓸 수 있을 때)

준비: Apple Developer Program 가입($99/년, 본인 Apple ID) · 맥에 Xcode(App Store) · Flutter.
(플러그인은 Swift Package Manager 로 붙어 CocoaPods 는 필요 없다. `ios/` 는 CI 가 이미 만들어 두었다.)

```
git pull
cd currency_app/flutter
flutter pub get
open ios/Runner.xcworkspace          # .xcodeproj 가 아니라 .xcworkspace
```

Xcode 에서:
1. **Xcode → Settings → Accounts** 에 본인 Apple ID 추가.
2. 왼쪽 Runner → TARGETS Runner → **Signing & Capabilities** → Team 에 본인 계정 선택,
   "Automatically manage signing" 체크. 인증서·프로파일은 Xcode 가 알아서 만든다.
3. 상단 기기 선택을 **Any iOS Device (arm64)** 로.
4. **Product → Archive** → 끝나면 Organizer 창 → **Distribute App → App Store Connect → Upload**.
   (본인 아이폰을 연결하고 ▶ 로 먼저 실행해 보면 광고 자리까지 확인할 수 있다.)

App Store Connect(appstoreconnect.apple.com)에서:
1. **My Apps → + → New App** — 이름 `한눈환율`(또는 원하는 이름), 번들 ID `com.soulfulfill.currency` 선택, SKU 아무거나(`somrate`).
2. 업로드된 빌드 선택, 스크린샷(6.7형 iPhone 최소 1장 — 실행한 폰에서 캡처), 설명, 키워드, 지원 URL.
3. **App Privacy**: 광고 SDK 가 있으므로 "식별자(기기 ID)·사용 데이터 수집 — 제3자 광고 목적" 으로 답한다.
   개인정보처리방침 URL → `https://hugoseong0721.github.io/test-mvp/somrate-privacy.html` (광고 문구 추가 필요).
4. 연령 등급 설문 전부 "없음" → 4+. 가격 무료.
5. **Submit for Review**. 보통 1~2일.

업데이트할 때는 `pubspec.yaml` 의 `version` 뒤 `+N` 을 올리고 같은 순서로 Archive → Upload.

## 로컬에서 돌려보기 (Flutter 설치된 PC)

```
cd currency_app/flutter
flutter pub get
flutter run                     # 연결된 폰/에뮬레이터
flutter build appbundle         # build/app/outputs/bundle/release/app-release.aab
dart run flutter_launcher_icons  # assets/icon 을 바꿨을 때 아이콘 재생성
```
