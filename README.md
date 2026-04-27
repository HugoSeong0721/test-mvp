# Test MVP

침술사 / 환자 웹 우선 MVP 프로젝트.

---

## 🔗 바로 가는 링크

| 용도 | 링크 |
|---|---|
| 🩺 **침술사용** (Hugo 본인 — 운영 화면) | **https://hugoseong0721.github.io/test-mvp/#/clinic** |
| 💛 **환자 / 친구 베타용** (가입 → 문진) | **https://hugoseong0721.github.io/test-mvp/#/patient** |
| 🏠 진입 허브 (두 카드 선택 화면) | https://hugoseong0721.github.io/test-mvp/ |

### 침술사 데모 계정
- ID: `123` / PW: `123`

### 환자/베타 사용법 (친구한테 보낼 때)
1. 위 환자 링크 클릭
2. 본인 이메일 + 비밀번호 **6자 이상** 으로 회원가입
3. 가입 후 자동으로 환자 홈 진입
4. 상단 탭에서 **문진** 클릭 → 작성 후 제출
5. 사용 중 문제 / 헷갈림 → 우하단 초록색 **피드백** 버튼으로 바로 보내기 (Hugo 메일로 자동 전송됨)

---

## 원격 저장소
- `https://github.com/HugoSeong0721/test-mvp.git`
- 배포: GitHub Pages (`docs/` 폴더에서 서빙)

## 이 컴퓨터에서 작업할 때
```bash
git add .
git commit -m "작업 내용"
git push
```

## 다른 컴퓨터에서 이어서 작업하기
1. Git 설치 확인 (`git --version`)
2. 원하는 폴더에서:
```bash
git clone https://github.com/HugoSeong0721/test-mvp.git
cd test-mvp
```
3. Flutter 의존성 설치:
```bash
flutter pub get
```
4. 웹 실행:
```bash
flutter run -d chrome
```

## 다른 컴퓨터에서 작업 후 동기화
```bash
git add .
git commit -m "작업 내용"
git push
```

## 원래 컴퓨터에서 최신 반영 받기
```bash
git pull
```
