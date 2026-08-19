# 솔랭 알림 — 경기 길이 표시 + 문구 통일 (플러터 작업 요청)

작성 2026-08-20. 백엔드는 **PR NAR-GG/nar-back-repo#428** 에 다 들어가 있고, 이 문서는 앱에서 할 두 가지를 합쳐 적었다.

1. 종료 알림에 **경기 길이** 표시 (`· 28분`)
2. 배너와 알림함의 **문구 통일** (`랭크 시작 감지!` 제거)

서버가 먼저 배포돼야 경기 길이가 실제 값으로 들어온다. 문구 통일은 서버 배포와 무관하게 진행할 수 있다.

---

## 배경 — 문구가 두 벌인 구조

솔랭 알림은 **문구가 두 곳에서 만들어진다.**

| | 만드는 곳 | 현재 문구 |
|---|---|---|
| 푸시 배너 | 서버 `title`/`body` | `Doran 선수가 솔랭을 시작했어요` / `올라프로 솔로 랭크 플레이 중` |
| 앱 알림함 | 앱 arb 조립 | `Doran 선수 랭크 시작 감지!` / `지금 Doran 선수가 올라프로 솔로 랭크를 시작했습니다` |

앱이 서버 `title`/`body` 를 버리고 `data` payload 로 다시 조립한다. 이유가 있다 — 서버 문구는 한국어 고정이라 영어 로케일을 못 맞춘다. 문제는 그 두 문구가 서로를 모르고 자라서 어긋난 것이다.

어긋난 지점 네 개:

| 축 | 배너 | 알림함 |
|---|---|---|
| 제목 종결 | `시작했어요` (해요체) | `감지!` (명사형·시스템체) |
| 본문 종결 | `플레이 중` (명사구) | `시작했습니다` (합니다체) |
| 주어 | 제목에만 | 제목·본문 양쪽 (`지금 Doran 선수가`) |
| 종료 제목 | `솔랭을 끝냈어요` | `솔랭 한 판을 마쳤어요` |

`감지!` 는 개발자 용어다. 사용자 문구에서 시스템 냄새를 뺀다.

---

## 목표 문구

**배너 기준으로 맞춘다.** 서버 문구가 이미 시작/종료 문체가 서로 맞고 짧다.

```
시작
  Doran 선수가 솔랭을 시작했어요
  올라프로 솔로 랭크 플레이 중

종료 (승패·KDA·길이 다 있음)
  Doran 선수가 솔랭을 끝냈어요
  베인으로 패배 · 10/5/3 · 28분

종료 (길이 없음)
  Doran 선수가 솔랭을 끝냈어요
  베인으로 패배 · 10/5/3

종료 (승패 불명)
  Doran 선수가 솔랭을 끝냈어요
  베인 경기 종료
```

### 종료 제목을 `끝냈어요` 로 바꾼 이유

기존 `솔랭 한 판을 마쳤어요` 는 서버 PR #428 에서 `솔랭을 끝냈어요` 로 이미 바뀌었다.

- `시작했어요` ↔ `끝냈어요` 로 대칭. 둘 다 타동사 + `을` 을 받아 문장 틀이 같아진다
- `마치다` 는 격식·절차 어감(수업을 마쳤다, 발표를 마쳤다). 솔랭 한 판에는 과하다
- `한 판을` 은 시작 문구에 없어 짝이 안 맞고, 알림 한 건이 게임 한 판이라 정보도 안 늘린다
- 원래 문구는 `app_en.arb` 의 `finished a solo queue game` 직역이었다

---

## 서버가 보내는 payload

앱이 문구를 조립할 때 쓰는 `data` 다. `gameDurationSeconds` 만 새로 추가됐다.

| 키 | 예시 | 없을 수 있음 |
|---|---|---|
| `type` | `PLAYER_SOLO_RANK_STARTED` | 아니오 |
| `eventType` | `START` / `END` | 아니오 |
| `playerName` | `Doran` | 아니오 |
| `championName` | `베인` | 아니오 |
| `queueType` | `솔로 랭크` | 아니오 |
| `win` | `"true"` / `"false"` | **예** — match-v5 결과를 못 읽으면 빠진다 |
| `kda` | `"10/5/3"` | **예** — 셋 다 있을 때만 |
| `gameDurationSeconds` | `"1694"` | **예** — 진행 중 매치·시계 이상이면 빠진다 |
| `playerId`, `gameId`, `deepLink`, `championImageUrl`, `opggUrl` | | 기존과 동일 |

주의할 것 둘:

- **`type` 은 시작·종료가 같다.** 딥링크 라우팅 키라 서버가 안 바꾼다. 구분은 `eventType` 으로만 한다 (이미 `isSoloRankEnd` 가 그렇게 되어 있다)
- **키가 빠질 수 있는 값은 반드시 null 분기를 둔다.** 구버전 서버와 붙어도 화면이 안 깨져야 한다

---

## 작업 1 — 경기 길이 표시

### 1-1. arb 키 추가

`lib/l10n/app_ko.arb`

```jsonc
"rankEndDurationMinutes": "{minutes}분",
"@rankEndDurationMinutes": {
  "description": "경기 길이. 본문 끝에 ' · 28분' 으로 덧붙는다. 초는 솔랭 결과에서 쓸모가 없어 분만 쓴다",
  "placeholders": {
    "minutes": { "type": "int" }
  }
},
```

`lib/l10n/app_en.arb`

```jsonc
"rankEndDurationMinutes": "{minutes}m",
"@rankEndDurationMinutes": {
  "description": "Game length appended to the body as ' · 28m'",
  "placeholders": {
    "minutes": { "type": "int" }
  }
},
```

**서버는 초로 싣고 표기 단위는 앱이 정한다.** `28:14` 로 바꾸고 싶어지면 서버 배포 없이 앱만 고치면 된다.

### 1-2. `lib/model/member_notification.dart`

`kda` getter 아래에 붙인다.

```dart
/// 경기 길이(초). 서버가 초로 싣고 표기 단위는 앱이 정한다.
/// 진행 중이거나 타임스탬프가 이상한 매치는 서버가 키를 빼므로 null 이다.
int? get gameDurationSeconds => int.tryParse(_d('gameDurationSeconds') ?? '');
```

`int.tryParse` 라서 키가 없거나(`''`) 값이 깨져도(`'abc'`) null 로 떨어진다.

### 1-3. `lib/screens/subscription/component/rank_end_notification.dart`

파라미터 추가:

```dart
/// 경기 길이(초). null 이거나 1분 미만이면 표기를 생략한다 —
/// '0분' 은 정보가 아니라 오해를 만든다.
final int? durationSeconds;
```

본문 조립에서 KDA 뒤에 붙인다:

```dart
final base = l.rankEndBodyResult(resolvedChampion, particle, result);
// KDA 는 언어와 무관한 숫자라 로케일 문구 뒤에 그대로 붙인다.
final withKda = (kda == null || kda!.isEmpty) ? base : '$base · $kda';
final minutes = (durationSeconds ?? 0) ~/ 60;
body = minutes < 1 ? withKda : '$withKda · ${l.rankEndDurationMinutes(minutes)}';
```

클래스 주석의 `[win] 과 [kda] 는 각각 없을 수 있다` 도 셋으로 갱신한다.

### 1-4. `lib/screens/subscription/subscription_screen.dart`

`RankEndNotification` 호출부에 한 줄:

```dart
durationSeconds: n.gameDurationSeconds,
```

### 표기를 생략하는 경우 3개

| 조건 | 이유 |
|---|---|
| 키 없음 | 진행 중 매치·시계 이상이면 서버가 빼고, 구버전 서버도 안 보낸다 |
| 1분 미만 | `0분` 은 정보가 아니라 오해를 만든다 |
| 승패 불명 | 본문이 `{챔피언} 경기 종료` 한 줄이라 붙일 자리가 없다 (위 코드에서 `win == null` 분기라 자동으로 생략됨) |

---

## 작업 2 — 문구 통일

### 2-1. `lib/l10n/app_ko.arb` — 키 3개 수정

```jsonc
// 시작 제목 — "감지!" 제거, 서버 문구와 동일하게
"rankStartTitle": "{playerName} 선수가 솔랭을 시작했어요",

// 시작 본문 — 주어 중복 제거, 명사구로. playerName 파라미터가 빠진다
"rankStartBody": "{champion}{particle} {queueType} 플레이 중",

// 종료 제목 — 서버 문구와 동일하게
"rankEndTitle": "{playerName} 선수가 솔랭을 끝냈어요",
```

`rankStartBody` 의 `@` 블록에서 `playerName` placeholder 를 지운다. `{queueType}를 시작했습니다` 에서 `를` 이 사라지므로 조사 파라미터(`particle`)는 챔피언 쪽 하나만 남는다.

**그대로 두는 키**: `rankEndBodyResult`, `rankEndBodyNoResult`, `rankEndWin`, `rankEndLose`. 종료 본문은 이미 서버와 같은 모양이다.

### 2-2. `lib/l10n/app_en.arb` — 같은 키 3개

한국어 직역이 아니라 영문 기준으로 자연스럽게 쓴다. 참고안:

```jsonc
"rankStartTitle": "{playerName} started a ranked game",
"rankStartBody": "Playing {queueType} as {champion}",
"rankEndTitle": "{playerName} finished a ranked game",
```

영문은 `끝냈어요`/`마쳤어요` 구분이 없어 `finished` 로 같다. 한국어에서만 갈리는 문제다.

### 2-3. `rank_start_notification.dart` 시그니처

`rankStartBody` 에서 `playerName` 이 빠지므로 호출이 바뀐다.

```dart
// before
body: l.rankStartBody(playerName, resolvedChampion, particle, resolvedQueue),
// after
body: l.rankStartBody(resolvedChampion, particle, resolvedQueue),
```

위젯의 `playerName` **필드는 유지한다** — 제목에 여전히 쓴다.

### 2-4. 남은 흔적 확인

```bash
grep -rn "감지" lib/l10n/
grep -rn "한 판을" lib/
```

둘 다 결과가 없어야 한다.

---

## `flutter gen-l10n`

`app_localizations*.dart` 가 커밋되는 저장소다. arb 를 고친 뒤 재생성해서 **함께 커밋한다.**

```bash
flutter pub get
flutter gen-l10n
```

`l10n.yaml` 이 있어서 커맨드라인 인자 없이 그대로 돌리면 된다.

---

## 테스트

### 갱신

- `test/screens/subscription/rank_start_notification_test.dart` — 제목·본문 기대 문구 전부 바뀐다
- `test/screens/subscription/rank_end_notification_test.dart` — 제목 기대 문구만 바뀐다(본문 단언은 그대로)

### 추가 — 위젯 4개

`rank_end_notification_test.dart` 의 `card()` 헬퍼에 `int? durationSeconds` 를 받게 하고:

```dart
testWidgets('경기 길이가 있으면 KDA 뒤에 분으로 덧붙인다', (tester) async {
  await tester.pumpWidget(card(win: true, kda: '18/1/11', durationSeconds: 1694));
  await tester.pumpAndSettle();
  expect(find.text('리 신으로 승리 · 18/1/11 · 28분'), findsOneWidget);
});

// 서버가 진행 중 매치·시계 이상이면 키를 빼고 보낸다. 구버전 서버도 키가 없다.
testWidgets('경기 길이가 없으면 기존 문구 그대로', (tester) async {
  await tester.pumpWidget(card(win: true, kda: '18/1/11'));
  await tester.pumpAndSettle();
  expect(find.text('리 신으로 승리 · 18/1/11'), findsOneWidget);
});

// '0분' 은 정보가 아니라 오해를 만든다.
testWidgets('1분 미만은 표기하지 않는다', (tester) async {
  await tester.pumpWidget(card(win: true, kda: '0/0/0', durationSeconds: 41));
  await tester.pumpAndSettle();
  expect(find.text('리 신으로 승리 · 0/0/0'), findsOneWidget);
  expect(find.textContaining('분'), findsNothing);
});

testWidgets('승패를 모르면 경기 길이도 붙이지 않는다', (tester) async {
  await tester.pumpWidget(card(durationSeconds: 1694));
  await tester.pumpAndSettle();
  expect(find.text('리 신 경기 종료'), findsOneWidget);
});
```

### 추가 — 모델 2개

`test/model/member_notification_test.dart`

```dart
test('솔랭 종료: gameDurationSeconds 를 읽는다', () { /* '1694' → 1694 */ });

// 서버가 진행 중 매치·시계 이상이면 키를 뺀다. 구버전 서버도 키가 없다.
test('솔랭 종료: 경기 길이 키가 없거나 깨지면 null', () {
  // {} / {'gameDurationSeconds': ''} / {'gameDurationSeconds': 'abc'} → 모두 null
});
```

### 실행

```bash
flutter test      # 기준선 325개 → 331개
flutter analyze   # 신규 이슈 0. 기존 3개(sentry_logger 2, main.dart 1)는 무관
```

---

## 안 하는 것

- **`type` 을 시작/종료로 쪼개지 않는다.** 딥링크 라우팅 키라 서버가 유지한다
- **알림함 전용 문구를 만들지 않는다.** 문구가 두 벌이면 다음에 또 한쪽만 고친다
- **리메이크 구분 표시**는 별건이다. `0/0/0 · 3분` 이 `패배` 로 나가는데, 서버가 `gameEndedInEarlySurrender` 를 실어줘야 구분할 수 있다

---

## 확인 방법

서버 PR #428 배포 후 추적 계정의 솔랭 게임이 하나 끝나면 **배너와 알림함을 나란히** 본다. 두 문구가 글자 단위로 같아야 한다.

받으려면:
- 서버 `SOLO_RANK_END_NOTIFICATION_ENABLED` = `true` (이미 켜져 있음)
- 본인 계정의 `member_favorite_player.end_enabled` = `1`

앱에서 켜는 경로는 `PUT /api/mobile/me/player-subscriptions/{playerId}` 에 `{"endEnabled": true}` 다. 토글 UI 가 아직 없으면 API 를 직접 호출하거나 DB 에서 바꾼다.

## 배포 순서 주의

서버 문구 변경(`끝냈어요`)이 먼저 배포되면 **앱 작업이 끝날 때까지 배너와 알림함이 다르게 보이는 기간**이 생긴다(배너는 `끝냈어요`, 알림함은 `한 판을 마쳤어요`). 이미 어긋나 있던 상태라 더 나빠지는 건 아니지만, 신경 쓰이면 앱 작업 완료에 맞춰 서버를 배포하면 된다.
