# Plan: Discord 에서 패치노트 확인하고 버튼으로 심사 제출

## Context

- Intent: 없음 (Spec 부터 시작했다)
- Spec: [spec.md](./spec.md)

## Changes

| 파일 | 내용 |
|---|---|
| `.github/workflows/release-deploy.yml` | `release-notes` 잡 추가(AI 초안) + `notify` 에 버튼 전송 |
| `.github/workflows/release-submit-dispatch.yml` | 신규. 버튼 요청을 받아 패치노트를 커밋하고 `submit-for-review.yml` 을 실행 |
| `tools/discord-bridge/api/discord/interactions.js` | `MESSAGE_COMPONENT` 핸들러 추가 (2단계 확인) |
| `tools/discord-bridge/api/discord/release.test.js` | 신규. `parseVersion`·`extractReleaseNotes` 테스트 |
| `distribution/README.md` | 양식과 AI 초안 설명 |

## 사람이 직접 해야 하는 선행 작업

버튼을 쓰려면 Secret 두 개가 필요하다. **없어도 동작한다** — 버튼 없이 초안만 온다.

- `DISCORD_BOT_TOKEN` — Discord Developer Portal → 해당 앱 → Bot → Token.
  `/intent` 를 처리하는 그 앱을 그대로 쓴다. 봇이 채널에 들어가 있어야 하고
  "메시지 보내기" 권한이 필요하다.
- `DISCORD_RELEASE_CHANNEL_ID` — 릴리즈 알림을 받을 채널 ID.
  Discord 에서 개발자 모드를 켜고 채널 우클릭 → "채널 ID 복사".

## Verification

- `flutter analyze && flutter test` — Dart 코드 변경이 없지만 기본 게이트로 돌린다.
- **bridge 단위 테스트 9개 통과** (`npm test`). `parseVersion` 이 `1.0.33` ·
  `x; rm -rf /` 같은 입력을 막는지, `extractReleaseNotes` 가 안내 문구를 패치노트로
  오인하지 않는지 확인했다.
- 워크플로우 3개 YAML 파싱 + 트리거·잡 그래프 확인.
- 버전 형식 검사와 "태그가 실제로 있는 버전인지" 검사를 실제 태그로 돌려 확인했다
  (`release/1.0.33+80` 통과 / `release/1.0.33+999` 차단).
- 여러 줄 초안이 `$GITHUB_OUTPUT` 히어독을 거쳐 Discord JSON 까지 `■`·줄바꿈을
  유지하는지 확인했다.

### 실제 동작은 첫 릴리즈에서 확인한다

버튼 흐름은 Discord·Vercel·GitHub 세 곳을 거쳐서, 머지만으로는 끝까지 검증되지 않는다.
첫 적용 순서:

1. `DISCORD_BOT_TOKEN`·`DISCORD_RELEASE_CHANNEL_ID` 등록.
2. 릴리즈 태그를 밀어 알림에 버튼이 실제로 붙는지 본다.
3. [심사 제출] → 확인 버튼이 뜨는지 본다. **여기서 멈춰도 아무것도 나가지 않는다.**
4. 확인까지 눌러 `release-submit-dispatch` 가 도는지 본다.
5. AI 초안 품질을 보고 프롬프트를 다듬는다.
