# ops — 계정이 바뀌어도 이어가기 위한 백업

Claude 계정(대화 세션·루틴)은 언제든 사라질 수 있다. 그래서 **다시 만들 수 있는 모든 것을 이 폴더에 둔다.**
GitHub(`soulfulfillable`)만 살아 있으면 새 Claude 계정에서 그대로 이어갈 수 있다.

## 무엇이 어디에 있나

| 것 | 사는 곳 | 계정 잃으면? | 백업 |
|---|---|---|---|
| 코드·문서·기획(`PRODUCT.md`, `CLAUDE.md`) | GitHub | 안전 | — (원본이 GitHub) |
| GitHub Actions 비밀값(App Store API 키 등) | GitHub 리포 설정 | 안전 | — |
| 대화 세션 기록 | Claude 계정 | **사라짐** | 중요한 결정은 세션이 끝나기 전 `PRODUCT.md` 결정 로그에 기록 (규칙: `CLAUDE.md`) |
| 루틴(주간 점검 등) | Claude 계정 | **사라짐** | `ops/routines/*.md` 에 일정·프롬프트 원문 보관. 새 세션형 루틴은 저장소 쓰기 권한이 안 붙어서, 기획 파트너 세션을 깨우는 방식으로 돌린다 |
| Claude 클라우드 환경 설정 | Claude 계정 | **사라짐** | 아래 "새 계정에서 복구" 참고 (특별한 설정 없음) |
| Apple 개발자·App Store Connect | Apple ID | Claude 와 무관 | ✅ 개인 Gmail 로 가입 (사용자 확인 2026-10-02) |
| AdMob(광고 수익 입금처) | Google 계정 | Claude 와 무관 | ⚠️ 개인 Gmail 둘 중 하나로 추정, 확인 필요 (admob.google.com 오른쪽 위 프로필) |

## 새 Claude 계정에서 복구 (5분)

1. 개인 이메일로 Claude 가입 → claude.ai/code 에서 GitHub `soulfulfillable` 연결.
2. `soulfulfillable/test-mvp` 로 새 세션을 열고 이렇게 말한다:
   **"ops/README.md 보고 복구해줘"**
3. 그 세션이 할 일: `ops/routines/` 의 루틴을 파일에 적힌 일정·프롬프트 그대로 다시 만들고,
   `PRODUCT.md` 를 읽어 기획 파트너로 이어서 일한다.
