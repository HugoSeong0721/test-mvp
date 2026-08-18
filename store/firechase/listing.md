# Climb or Burn — 스토어 등록 문구

Play Console의 「기본 스토어 등록정보」에 그대로 붙여넣는 용도.
**기본 언어는 English (United States)** 로 등록한다. 게임 UI가 전부 영어이므로 그에 맞춘다.

---

## English (en-US) — 기본 등록정보

### App name (30 chars)

```
Climb or Burn
```

`Fire Escape`는 동명 앱이 많아 피했다. 게임 시작 화면의 제목과도 일치한다.

### Short description (80 chars)

```
The fire never stops rising. Hit the ledges and keep climbing, or burn.
```

### Full description (4000 chars)

```
Stop moving and you burn.

Fire rises from below and it never slows down. Hit the ledges, climb higher,
and keep climbing. Hesitate for a second and the flames reach your feet.

■ One thumb, no tutorial
Hold the left or right side of the screen. That is the whole control scheme.
Jumping is automatic. You pass through the side walls. Nothing to learn.

■ Runs are short
Thirty seconds to a minute. On the train, waiting for an elevator, before bed.
Die and you are back in instantly.

■ No safe moments
The fire never slows. The higher you go, the further apart the ledges get.
Giving you no room to relax is the entire point of this game.

■ Chase the record
Your best altitude is saved. Check your standing on the leaderboard and share
your run to challenge a friend under the same conditions.

■ Challenge mode
Enter a challenge code to start on identical terrain.
For when you want the result decided by skill instead of luck.

■ Light
Works with no internet connection. No account, no sign-in.
Collects no personal information.

Now run.
```

---

## 그래픽 자산

| 파일 | 규격 | 용도 |
|---|---|---|
| `icon-512.png` | 512×512 RGBA | 앱 아이콘 |
| `feature-1024x500.png` | 1024×500 RGB | 그래픽 이미지 |
| `01-start.png` ~ `04-gameover.png` | 1080×2160 | 폰 스크린샷 4장 |

스크린샷은 영어판을 실제로 플레이해서 캡처한 것이다.

---

## 등록 시 주의

### 언어

게임 UI를 전부 영어로 바꿨다. 화면에 한국어는 남아 있지 않다.
따라서 **한국어 등록정보는 추가하지 않는다.** 한국어로 등록하면 한국 사용자가
한국어 앱으로 기대하고 받았다가 영어 화면을 보게 되어 별점이 깎인다.

나중에 게임에 한국어를 다시 넣게 되면 그때 한국어 등록정보를 추가한다.
한국어 문구 원본은 이 파일의 git 이력에 남아 있다.

### 콘텐츠 등급 설문

- 폭력 표현 없음 · 성적 콘텐츠 없음 · 언어 표현 없음 · 도박 요소 없음
- 사용자 간 소통 기능 없음 (랭킹은 기기 안에만 저장)
- 광고 SDK를 넣으면 **광고 ID 수집**으로 답해야 한다
- 대상 연령 **13세 이상** — `docs/privacy.html`이 13세 미만 비대상으로 작성되어 있으므로
  콘솔에서도 동일하게 맞출 것

### 이름 일치

앱 이름 `Climb or Burn`은 아래 세 곳에서 같아야 한다. 어긋나면 심사에서 지적받는다.

- Play Console 스토어 등록정보
- 게임 시작 화면 제목
- `docs/privacy.html`의 적용 대상 앱 목록
