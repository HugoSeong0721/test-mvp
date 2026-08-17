# Climb or Burn — 안드로이드 앱

`docs/firechase.html` 을 오프라인 자산으로 넣은 WebView 앱.
게임이 외부 의존성 없는 단일 HTML 이라 인터넷 없이 완결된다.

**이 프로젝트는 이 저장소에서 빌드되지 않았다.** 컨테이너에 Android SDK 가 없고
설치처(`dl.google.com`)가 네트워크 정책에 막혀 있다. 소스는 완성돼 있으니
안드로이드 스튜디오에서 열어 빌드하면 된다.

---

## 빌드 순서

1. **Android Studio** 최신 버전 설치 (Ladybug 이상)
2. `File → Open` → 이 폴더(`android/climb-or-burn`) 선택
3. 첫 실행 때 Gradle 과 SDK 를 자동으로 받는다 (10~20분)
4. 안드로이드 기기를 USB 로 연결하고 `Run ▶`

## Play 업로드용 AAB 만들기

Play 는 APK 가 아니라 **AAB** 를 받는다.

1. `Build → Generate Signed App Bundle / APK` → **Android App Bundle**
2. `Create new...` 로 키스토어 생성
3. **키스토어 파일과 비밀번호를 반드시 따로 백업할 것.**
   잃어버리면 이 앱을 영원히 업데이트할 수 없다. 새 앱으로 다시 올려야 하고
   설치 수와 리뷰도 전부 처음부터다. 이 프로젝트에서 되돌릴 수 없는 유일한 실수다.
4. `release` 선택 → 생성된 `app/release/app-release.aab` 를 Play Console 에 업로드

## 구조

```
app/src/main/
├── AndroidManifest.xml          권한 선언 없음
├── assets/game/index.html       게임 본체 (docs/firechase.html 사본)
├── java/.../MainActivity.kt     전체화면 WebView + 공유 연결
└── res/
    ├── mipmap-*/                런처 아이콘 (레거시 + 적응형 전경)
    ├── mipmap-anydpi-v26/       적응형 아이콘 정의
    └── values/                  이름·색·테마
```

## 알아둘 것

### 게임을 고치면 자산도 같이 바꿔야 한다

`docs/firechase.html` 과 `app/src/main/assets/game/index.html` 은 **사본 관계**다.
웹 쪽만 고치면 앱은 옛 버전 그대로 나간다.

```bash
cp docs/firechase.html android/climb-or-burn/app/src/main/assets/game/index.html
```

### 권한을 하나도 선언하지 않았다

게임이 전부 오프라인이라 인터넷 권한조차 필요 없다.
`docs/privacy.html` 에 "수집하지 않는다"고 적어둔 것과 이 상태가 맞아떨어진다.

**애드몹을 붙이는 순간** `INTERNET` 과 `ACCESS_NETWORK_STATE` 가 필요해지고,
Play Console 의 데이터 보안 양식도 "광고 ID 수집"으로 고쳐야 한다.
셋 중 하나만 어긋나도 심사에서 걸린다.

### 공유 버튼

WebView 에는 `navigator.share` 가 없어서 게임의 공유 버튼이 수동 복사로 떨어진다.
`MainActivity` 가 폴리필을 주입해 안드로이드 공유 시트로 연결한다.

이때 링크를 `file:///android_asset/...` 대신 웹 주소로 바꿔 보낸다.
앱 내부 경로를 그대로 보내면 받는 사람이 열 수 없기 때문이다.
도전 코드 해시(`#c=29`)는 그대로 유지되므로 상대가 같은 지형에서 시작한다.

`ShareBridge` 는 리플렉션으로 호출되므로 `proguard-rules.pro` 에서 난독화 제외해 뒀다.
이 규칙을 지우면 **릴리스 빌드에서만** 공유가 조용히 죽는다.

### 버전 올리기

`app/build.gradle.kts` 의 `versionCode` 를 매 업로드마다 1씩 올린다.
같은 값으로는 Play 가 거부한다.

## 검증한 것

컨테이너에서 빌드는 못 했지만 아래는 헤드리스 Chromium 으로 확인했다.

- 게임이 assets 경로에서 정상 로드 (`Climb or Burn`)
- `localStorage` 동작 — 최고 점수 저장이 `file://` 에서도 된다
- 공유 폴리필 구문 오류 없음, `file://` 이 웹 주소로 치환되고 `#c=29` 유지
- XML 8개 전부 파싱 통과

**빌드·설치·실기기 동작은 확인하지 못했다.** 처음 실행할 때 확인할 것:
전체화면으로 뜨는지, 터치 드래그 조작이 되는지, 소리가 나는지,
앱을 껐다 켰을 때 최고 점수가 남아 있는지.
