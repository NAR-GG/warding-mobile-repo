# Plan: Discord 에서 패치노트 확인하고 버튼으로 심사 제출

## Context

- Intent: 없음 (Spec 부터 시작했다)
- Spec: [spec.md](./spec.md)

## Changes

| 파일 | 내용 |
|---|---|
| `.github/workflows/release-deploy.yml` | `release-notes` 잡 추가(AI 초안) + `notify` 에 버튼 전송 |
| `.github/workflows/release-submit-dispatch.yml` | 신규. 버튼 요청을 받아 패치노트를 커밋하고 `submit-for-review.yml` 을 실행 |
| `tools/discord-bridge/api/discord/release.js` | 신규. **배포 전용 봇** 엔드포인트 (버튼 2단계 확인) |
| `tools/discord-bridge/lib/http.js` | 신규. 두 핸들러가 같이 쓰는 HTTP 헬퍼·dispatch |
| `tools/discord-bridge/api/discord/release.test.js` | 신규. `parseVersion`·`extractReleaseNotes` 테스트 |
| `distribution/README.md` | 양식과 AI 초안 설명 |

## 사람이 직접 해야 하는 선행 작업

버튼을 쓰려면 Secret 두 개가 필요하다. **없어도 동작한다** — 버튼 없이 초안만 온다.

**배포 전용 봇을 새로 만든다.** `/intent` 봇과 섞지 않는다.

1. [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**
   (이름 예: `Warding Release`)
2. **Bot** 탭 → **Reset Token** → 토큰 복사 → `DISCORD_BOT_TOKEN`
3. **General Information** → **Public Key** 복사 → `DISCORD_RELEASE_PUBLIC_KEY`
4. **General Information** → **Interactions Endpoint URL** 에 아래를 넣고 저장
   (저장할 때 Discord 가 PING 을 보내 검증한다 — 3번을 먼저 등록해야 통과한다)
   ```
   https://<vercel-도메인>/api/discord/release
   ```
5. **OAuth2 → URL Generator** 에서 `bot` 스코프 + `Send Messages` 권한으로 초대 링크를
   만들어 서버에 봇을 넣는다.
6. 릴리즈 알림을 받을 채널에서 개발자 모드를 켜고 우클릭 → **채널 ID 복사** →
   `DISCORD_RELEASE_CHANNEL_ID`

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
