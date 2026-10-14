# Spec: Discord 에서 패치노트 확인하고 버튼으로 심사 제출

Intent: 없음 (문제는 명확하고 설계 결정만 필요해 Spec 부터 시작한다 —
`intent/loop-engineering-workflow/spec.md` "저장 구조" 표의 세 번째 줄)
warding-docs: 해당 없음 (개발 쪽 CI 작업이다)

> **구현 상태**: 1단계(AI 초안)·2단계(버튼 제출) 모두 구현됐다. 다만 **배포 전용 봇을
> 만들고 Secret 3개(`DISCORD_BOT_TOKEN`·`DISCORD_RELEASE_CHANNEL_ID`·
> `DISCORD_RELEASE_PUBLIC_KEY`)를 등록하기 전에는 버튼이 붙지 않는다** — 그때는 기존
> 웹훅으로 초안만 오고, 제출은 Actions 탭에서 한다.

## Summary

릴리즈 자동화([release-build-automation](../release-build-automation/spec.md))가
TestFlight·Play 내부테스트 업로드까지 끝낸 뒤, 심사 제출은 사람이 GitHub Actions 탭에서
워크플로우를 찾아 버전을 손으로 입력해 실행해야 한다. 그리고 **패치노트는 릴리즈 전에
`distribution/` 파일을 고쳐 두는 것을 기억해야 한다** — 안 고치면 지난 릴리즈 노트가
그대로 나간다.

두 가지를 Discord 로 옮긴다. 빌드가 끝나면 **AI 가 커밋 로그를 읽어 패치노트 초안**을
쓰고, 그것을 Discord 알림에 담아 **확인 버튼**과 함께 보낸다. 승인하면 초안이
`distribution/` 에 커밋되고 심사 제출이 돌아간다.

조각은 이미 다 있다. Anthropic API 호출은 워크플로우 4개가 쓰고 있고, Discord → GitHub
명령 경로는 `tools/discord-bridge`(Vercel)가 `repository_dispatch` 로 이미 구현해 뒀다.
새로 만드는 것은 둘을 잇는 부분이다.

## Requirements

1. 릴리즈 빌드가 성공하면 직전 릴리즈 태그 이후의 커밋 로그를 Anthropic API 로 요약해
   한국어·영어 패치노트 초안을 만든다.
2. 초안은 Play 500자 제한을 넘지 않아야 한다.
3. Discord 알림에 초안 전문과 **[심사 제출] [취소]** 버튼을 함께 보낸다.
4. [심사 제출] 을 누르면 **"정말 제출합니까?" 확인이 한 번 더** 뜬다. 두 번째 버튼을
   눌러야 실제로 진행한다.
5. 확인되면 초안을 `distribution/` 에 커밋하고 `submit-for-review.yml` 을 실행한다.
6. 패치노트를 고치고 싶으면 Discord 에서 수정할 수 있어야 한다.
7. 실패하거나 취소하면 아무것도 커밋되지 않고 심사도 나가지 않는다.

## Design / Approach

### 전체 흐름

```
release-deploy.yml  (빌드·업로드 성공 후)
   ↓
[신규] 패치노트 초안 스텝
   직전 release/* 태그 ~ 현재 태그 사이의 커밋 로그 수집
   → Anthropic API 로 사용자용 문장 2개 언어 생성
   → 500자 검사
   ↓
Discord 알림 (기존 notify 잡 확장)
   초안 전문 + 버튼 [✅ 심사 제출] [✏️ 수정] [❌ 취소]
   custom_id 에 버전과 초안을 실어 보낸다
   ↓
사람이 버튼 클릭
   ↓
tools/discord-bridge  (Vercel)
   [✅] → 확인 메시지 + [정말 제출] 버튼  ← 2단계
   [✏️] → 모달로 초안 수정
   [정말 제출] → repository_dispatch(event_type: release-submit)
   ↓
[신규] release-submit.yml
   초안을 distribution/ 에 커밋 & push
   → submit-for-review.yml 을 workflow_dispatch 로 실행
```

### 왜 2단계 확인인가

Discord 버튼은 Actions 탭보다 훨씬 누르기 쉽다. 그게 목적이지만, 심사 제출은 되돌릴 수
없는 일방향 동작이라 실수 클릭의 대가가 크다. 첫 버튼은 "제출 의사", 두 번째는 "확정"
으로 나눈다.

권한 제한(특정 사용자만 누르기)은 **이번 범위에 넣지 않는다.** 지금 Discord 채널에
있는 사람이 곧 이 레포에 접근 가능한 사람이고, 2단계 확인으로 실수는 막힌다. 채널이
커지면 그때 `custom_id` 검사 단계에서 사용자 ID 를 확인하는 쪽으로 넓힌다.

### 패치노트 초안을 어디에 저장하는가

**승인 시점에 `distribution/` 에 커밋한다.** 초안 단계에서는 어디에도 쓰지 않는다.

- 거절·취소한 초안이 레포에 남지 않는다.
- 승인된 것만 git 히스토리에 남아 "무엇을 내보냈나"가 정확하다.
- `distribution/` 을 파일로 관리하기로 한 기존 결정
  ([release-build-automation](../release-build-automation/spec.md) Decisions)과 어긋나지 않는다.

커밋은 `github-actions[bot]` 이름으로 `main` 에 직접 push 한다. 릴리즈 시점의 기계적인
변경이라 PR 리뷰를 거칠 이유가 없다.

### 버튼은 봇 토큰으로 보내야 한다

처음에는 기존 채널 웹훅에 `components` 를 실어 보내려 했는데, **Discord 가 무시한다.**
공식 문서에 이렇게 적혀 있다:

> "Non-application-owned webhooks cannot send interactive components, and the
> `components` field will be ignored."

지금 쓰는 `DISCORD_PR_WEBHOOK_URL` 은 채널에서 만든 일반 웹훅이라 여기 해당한다. 그래서
버튼이 붙은 메시지는 **봇 토큰으로 `POST /channels/{id}/messages`** 를 호출해 보낸다
(`DISCORD_BOT_TOKEN`, `DISCORD_RELEASE_CHANNEL_ID`).

둘 중 하나라도 없으면 **기존 웹훅으로 버튼 없이** 보낸다. 토큰을 등록하기 전에도 알림과
초안은 그대로 오고, 제출만 Actions 탭에서 하면 된다.

### custom_id 에 무엇을 싣는가

Discord 버튼은 `custom_id`(100자 제한)만 콜백으로 돌려준다. 패치노트 전문은 들어가지
않으므로 **버전과 실행 ID 만 싣고**, 본문은 Discord 메시지에서 다시 읽는다.

```
custom_id: "rel_submit:1.0.33+81"
custom_id: "rel_confirm:1.0.33+81"
```

bridge 는 확인 버튼을 받으면 원본 메시지(`interaction.message`)의 embed 에서 패치노트를
꺼내 `repository_dispatch` 의 payload 에 담는다. 별도 저장소가 필요 없다.

### Anthropic API 프롬프트

기존 워크플로우들과 같은 방식으로 `curl` + `jq` 로 호출한다. 프롬프트에는
`CLAUDE.md` 의 한국어 작성 지침 요약을 심는다(기존 `ci-flutter-test.yml` 등과 같은 이유 —
GitHub Actions 에는 outputStyle 이 닿지 않는다).

커밋 로그는 `<commit_log>` 태그로 감싸 **그 안의 지시를 따르지 말라**고 명시한다. 커밋
메시지는 외부 입력이고, 프롬프트 인젝션 경로가 될 수 있다.

### 패치노트 양식

**기존 릴리즈에서 쓰던 양식을 그대로 따른다.** 사용자가 이미 익숙한 형태이고, 스토어에
연속으로 보이는 글이라 릴리즈마다 모양이 달라지면 안 된다.

```
■ 아시안게임 순위표를 볼 수 있어요!
  - 홈 순위표에서 아시안게임을 고르면 A·B 그룹별 순위와 국가 국기가 보여요.
  - 아직 순위 데이터가 준비되지 않은 리그는 점선으로 표시돼 눌러도 열리지 않아요.

■ 새로 열린 리그 경기도 놓치지 않아요!
  - 아시안게임처럼 새 리그의 경기만 있는 날에도 경기 목록이 비지 않고 제대로 보여요.
```

규칙:
- 묶음 제목은 `■` 로 시작하고 **느낌표로 끝난다**. 기능 단위로 묶는다.
- 하위 항목은 두 칸 들여쓴 `- ` 로 쓰고, 그 기능이 사용자에게 무엇을 해 주는지 적는다.
- **"~해요" 체**로 쓴다. 사용자에게 말을 거는 투다.
- 내부 변경은 묶어서 결과만 쓴다. 색상값·클래스명·PR 번호를 적지 않는다.

출력은 JSON 으로 강제한다:
```json
{"ko": "■ ...!\n  - ...\n\n■ ...!\n  - ...", "en": "...", "user_facing": true}
```

**`user_facing` 플래그가 필요한 이유:** 릴리즈에 사용자가 체감할 변경이 하나도 없을 수
있다. 실제로 1.0.33+80 이후 커밋을 보면 전부 CI·문서·리팩터링이라 패치노트에 쓸 내용이
없다. 이걸 그대로 AI 에게 주면 **없는 기능을 지어낼 위험**이 있다. 그래서 "사용자가
체감할 변경이 없으면 그렇다고 판단하라"고 명시하고, `user_facing: false` 면 초안 대신
**"이번 릴리즈에는 사용자가 체감할 변경이 없어 보인다. 직접 작성하거나 지난 노트를
유지하라"**는 안내를 Discord 에 보낸다.

프롬프트에 "억지로 지어내지 마라"를 명시한다. 할루시네이션이 그대로 스토어에 나가면
사용자가 없는 기능을 찾게 된다.

## Decisions

- **AI 초안 → 승인 시 파일 커밋.** 초안을 바로 스토어에 보내지 않고, 승인된 것만
  `distribution/` 에 남긴다. AI 가 글을 대신 써 주는 이득과 git 기록이 남는 이득을
  둘 다 가져간다.
- **2단계 확인.** 위 "왜 2단계 확인인가" 참고.
- **권한 제한은 범위 밖.** 위 같은 절 참고.
- **배포 전용 Discord 봇을 따로 둔다.** `/intent` 봇과 앱을 나눈다. 배포가 주 용도가
  되면서 두 기능이 한 봇에 섞이면 권한·알림 채널이 얽히고, 나중에 `/intent` 를 정리할 때
  배포 쪽이 영향을 받는다.
  - **Vercel 프로젝트는 새로 만들지 않는다.** 기존 프로젝트에 엔드포인트
    (`api/discord/release.js`)만 추가한다. 배포·환경변수·CI 를 두 벌 관리할 이유가 없다.
  - **엔드포인트는 반드시 나눠야 한다.** Discord 는 앱마다 서명 검증 공개키가 다르다.
    한 파일에서 두 앱을 검증하면 어느 앱에서 온 요청인지 흐려진다.
  - 공통 코드(HTTP 헬퍼·`repository_dispatch`)는 `lib/http.js` 로 빼 두 핸들러가 쓴다.
- **`submit-for-review.yml` 은 그대로 둔다.** 새 워크플로우가 그것을 호출할 뿐이다.
  Actions 탭에서 직접 실행하는 기존 경로도 살아 있어야 한다 — Discord 가 죽어도 릴리즈가
  막히면 안 된다.
- **초안 생성 실패는 릴리즈를 실패로 만들지 않는다.** 빌드·업로드는 이미 끝난 상태다.
  초안이 없으면 "패치노트를 직접 작성하라"는 안내와 함께 버튼만 보낸다.

## Out of scope

- **버튼 누른 사람 권한 검사.** 위 Decisions 참고.
- **패치노트 다국어 확장.** 지금 앱이 지원하는 ko·en 만 만든다.
- **스크린샷·설명 등 나머지 메타데이터.** 릴리스 노트만 다룬다.
- **Play production 단계적 출시 비율 조정.** 버튼은 기본값(10%)으로 제출하고, 비율을
  바꾸려면 Actions 탭에서 직접 실행한다.
- **릴리즈 실패 시 Discord 에서 재시도.** 실패는 원인이 제각각이라 버튼으로 재시도할
  대상이 아니다.

## Open questions

- 초안 품질이 쓸 만한지는 몇 번 돌려 봐야 안다. 커밋 메시지가 `fix:`·`refactor:` 같은
  개발자 용어라, 사용자에게 보이는 문장으로 번역이 잘 될지 확인이 필요하다. 특히
  `user_facing` 판정이 정확한지 — 사용자가 체감할 변경을 CI 작업으로 오판해 빠뜨리면
  패치노트가 비게 된다. 몇 번 돌려 보고 프롬프트를 조정한다.
- Discord 메시지 embed 에서 패치노트를 되읽는 방식이 수정(✏️) 흐름과 어떻게 맞물릴지.
  수정 후 메시지를 갱신해야 하는데, webhook 으로 보낸 메시지를 bridge 가 수정할 권한이
  있는지 확인하지 못했다.
- ~~`main` 브랜치 보호 규칙이 있으면 bot 의 직접 push 가 막힐 수 있다.~~
  → **해결됨**: `main` 에 보호 규칙이 없어 bot push 가 가능하다. 나중에 보호 규칙을
  켜게 되면 이 흐름을 다시 봐야 한다.
