# 솔랭 알림 문구 통일 (플러터 작업 요청)

작성 2026-08-20. 서버 쪽 변경은 백엔드 PR #428 에 포함돼 있고, 이 문서는 앱에서 해야 할 부분만 적었다.

## 문제

솔랭 알림 문구가 **푸시 배너와 앱 알림함에서 다르게 나온다.** 배너는 서버 `title`/`body` 를 그대로 쓰지만, 알림함은 앱이 `data` payload 로 문구를 다시 조립한다(로케일 대응 때문). 그 두 문구가 서로를 모르고 자라서 어긋났다.

**푸시 배너 (서버 문구)**

```
Doran 선수가 솔랭을 시작했어요
올라프로 솔로 랭크 플레이 중
```

**앱 알림함 (앱 문구)**

```
Doran 선수 랭크 시작 감지!
지금 Doran 선수가 올라프로 솔로 랭크를 시작했습니다
```

같은 알림인데 제목·본문이 전부 다르다. 어긋난 지점이 네 개다.

| 축 | 배너 | 알림함 |
|---|---|---|
| 제목 종결 | `시작했어요` (해요체) | `감지!` (명사형·시스템체) |
| 본문 종결 | `플레이 중` (명사구) | `시작했습니다` (합니다체) |
| 주어 | 제목에만 | 제목·본문 양쪽에 (`지금 Doran 선수가`) |
| 큐 표기 | `솔로 랭크` | `솔로 랭크` (같음) |

`감지!` 는 개발자 용어다. 사용자에게 보이는 문구에서 시스템 냄새를 빼는 게 맞다.

## 목표

**배너와 알림함이 같은 문구를 쓴다.** 기준은 서버 문구(배너)에 맞춘다 — 이미 시작/종료 문체가 서로 맞고 짧다.

```
시작   Doran 선수가 솔랭을 시작했어요
       올라프로 솔로 랭크 플레이 중

종료   Doran 선수가 솔랭을 끝냈어요
       베인으로 패배 · 10/5/3 · 28분

종료(승패 불명)
       Doran 선수가 솔랭을 끝냈어요
       베인 경기 종료
```

종료 제목을 `솔랭 한 판을 마쳤어요` → `솔랭을 끝냈어요` 로 바꿨다(서버 PR #428 에 반영됨). 이유:

- `시작했어요` ↔ `끝냈어요` 로 대칭이 맞는다. 둘 다 타동사 + `을` 을 받아 문장 구조가 같아진다
- `마치다` 는 격식·절차의 어감이 있다(수업을 마쳤다, 발표를 마쳤다). 솔랭 한 판에는 과하다
- `솔랭 한 판을` 의 `한 판을` 은 시작 문구에 없어 길이·구조가 어긋났고, 알림 한 건이 게임 한 판이라 정보도 안 늘린다
- `finished a solo queue game` 의 직역이었다(`app_en.arb` 의 `rankEndTitle` 참고)

## 고칠 것

### 1. `lib/l10n/app_ko.arb`

```jsonc
// 시작 — "감지!" 제거, 서버 문구와 동일하게
"rankStartTitle": "{playerName} 선수가 솔랭을 시작했어요",

// 시작 본문 — 주어 중복 제거, 명사구로
"rankStartBody": "{champion}{particle} {queueType} 플레이 중",

// 종료 — 서버와 동일하게
"rankEndTitle": "{playerName} 선수가 솔랭을 끝냈어요",
```

`rankStartBody` 의 `particle` 은 지금도 있는 파라미터다(`particleEuro`). `올라프` + `로` → `올라프로`. `{queueType}를 시작했습니다` 에서 `를` 이 사라지므로 조사 파라미터는 챔피언 쪽 하나만 남는다.

`rankEndBodyResult`·`rankEndBodyNoResult`·`rankEndWin`·`rankEndLose`·`rankEndDurationMinutes` 는 **그대로 둔다.** 종료 본문은 이미 서버와 같은 모양이다.

### 2. `lib/l10n/app_en.arb`

같은 키 3개를 영문으로 맞춘다. 현재 영문이 한국어의 직역인지 확인하고, 어색하면 영문 기준으로 다시 쓰는 게 낫다. 예:

```jsonc
"rankStartTitle": "{playerName} started a ranked game",
"rankStartBody": "Playing {queueType} as {champion}",
"rankEndTitle": "{playerName} finished a ranked game",
```

영문은 `끝냈어요`/`마쳤어요` 구분이 없어 `finished` 로 같다. 한국어에서만 갈리는 문제다.

### 3. `flutter gen-l10n`

`app_localizations*.dart` 가 커밋되는 구조라 재생성해서 함께 커밋한다.

### 4. `lib/screens/subscription/component/rank_start_notification.dart`

본문 조립이 `l.rankStartBody(playerName, resolvedChampion, particle, resolvedQueue)` 인데 `playerName` 파라미터가 빠지므로 시그니처가 바뀐다. 위젯 자체의 `playerName` 필드는 제목에 여전히 필요하니 유지한다.

### 5. 테스트

`test/screens/subscription/rank_start_notification_test.dart` 의 기대 문구를 갱신한다. 종료 카드 테스트(`rank_end_notification_test.dart`)는 제목 문구만 갱신하면 된다 — 본문 단언은 안 바뀐다.

`감지` 라는 단어가 어디에도 남지 않는지 확인:

```bash
grep -rn "감지" lib/l10n/
```

## 서버가 보내는 것 (참고)

앱이 문구를 조립할 때 쓰는 `data` payload 다. 이번에 바뀌는 건 없고, 경기 길이만 PR #428 에서 새로 추가됐다.

| 키 | 값 | 비고 |
|---|---|---|
| `type` | `PLAYER_SOLO_RANK_STARTED` | 시작·종료 공통. 딥링크 라우팅 키라 서버가 안 바꾼다 |
| `eventType` | `START` / `END` | **시작·종료 구분은 이것으로만 한다** |
| `playerName` | `Doran` | |
| `championName` | `베인` | 한국어 고정. 영문은 앱이 `championToEn` 으로 변환 |
| `queueType` | `솔로 랭크` | 시작 알림에만 의미 있음 |
| `win` | `"true"` / `"false"` | 종료. match-v5 결과를 못 읽으면 **키 없음** |
| `kda` | `"10/5/3"` | 종료. 셋 다 있을 때만 |
| `gameDurationSeconds` | `"1694"` | 종료. 진행 중·시계 이상이면 **키 없음** (PR #428) |
| `championImageUrl`, `opggUrl`, `deepLink`, `playerId`, `gameId` | | 기존과 동일 |

**키가 없을 수 있는 값(`win`·`kda`·`gameDurationSeconds`)은 반드시 null 분기를 둔다.** 구버전 서버와 붙어도 화면이 깨지지 않아야 한다.

## 안 하는 것

- **`type` 을 시작/종료로 쪼개지 않는다.** 딥링크 라우팅 키라 서버가 유지하고, 구분은 `eventType` 이 한다
- **알림함 전용 문구를 따로 만들지 않는다.** 문구가 두 벌이면 다음에 또 한쪽만 고친다. 배너와 같은 문구를 쓴다
- **리메이크 표시**는 이번 범위가 아니다. `0/0/0 · 3분` 이 `패배` 로 나가는데, 서버가 `gameEndedInEarlySurrender` 를 실어줘야 구분할 수 있다

## 확인 방법

서버 PR #428 이 배포된 뒤 추적 계정의 솔랭 게임이 하나 끝나면 배너와 알림함을 나란히 본다. 두 문구가 글자 단위로 같아야 한다.

`SOLO_RANK_END_NOTIFICATION_ENABLED` 는 이미 `true` 이고, 받으려면 본인 계정의 `member_favorite_player.end_enabled` 가 `1` 이어야 한다.
