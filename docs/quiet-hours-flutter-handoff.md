# 알림 잠자기 — 플러터 작업 요청서

정한 시간대에는 모든 푸시를 소리 없이 보내 알림함에만 쌓는 기능입니다.
백엔드는 완료됐고, **Android 무음은 앱이 알림 채널을 만들어야 동작합니다.** 설정 화면도 앱 몫입니다.

| | |
|---|---|
| 백엔드 브랜치 | `feat/notification-quiet-hours` (머지 대기) |
| iOS | 앱 작업 없음 |
| 예상 | 1~1.5일 |
| UI 목업 | https://claude.ai/code/artifact/7689e6d6-0c07-48fc-aae0-b9739097cb15 |

목업은 앱 실측 토큰(`AppColors`, `NarToggle` 스펙)으로 그렸습니다. 카드 상태·문구·시트 구조 그대로 쓰시면 됩니다.

## 배경

"밤에도 솔랭 알림이 너무 많이 온다"는 문의가 들어왔습니다. 선수 한 명이 한 번 앉으면 3~4판을
연속으로 돌리고 감지 대상 선수가 여럿이라 새벽에 알림이 겹칩니다. 지금 유저가 조절할 수 있는 건
선수 구독 on/off뿐이라 "이 선수 알림은 받고 싶지만 새벽엔 조용했으면"을 표현할 방법이 없습니다.

알림을 **버리지 않고 소리만 죽입니다**(YouTube "알림 사용 안 함 시간대" 방식). 알림함에는 그대로 쌓입니다.
그리고 **알림 종류를 가리지 않습니다** — 솔랭·경기 시작/종료·라이브 이벤트 전부.
"정한 시간엔 조용하다" 한 문장이 유저가 이해할 유일한 모델이라서요.

---

## 먼저 읽어주세요 — 여기 틀리면 알림이 유실됩니다

1. **Android 채널 id는 정확히 `warding_quiet`** 입니다. 서버가 무음 발송 시 이 문자열을
   `android.notification.channel_id`로 보냅니다. 한 글자라도 다르면 Android가 알림을
   **띄우지 못합니다**(존재하지 않는 채널). 조용해지는 게 아니라 사라집니다.

2. **잠자기 기본값은 OFF입니다.** 서버 컬럼 기본값이 0이고 앱에서도 기본 OFF로 보여야 합니다.
   이건 취향이 아니라 안전장치입니다 — 서버는 기기의 앱 버전을 모르므로
   "잠자기가 켜져 있다 = 신버전 앱이다"가 성립해야 구버전 기기에 없는 채널 id를 보내지 않습니다.
   **기본값을 ON으로 바꾸지 말아주세요.**

3. **Android O+ 는 채널 설정이 서버 payload보다 우선합니다.** 서버가 소리를 비우고 priority를
   낮춰도, 채널 importance가 high면 시스템이 채널 설정대로 소리를 냅니다. 그래서 채널을 따로
   만들어야 하고, 채널은 한 번 생성되면 앱이 코드로 importance를 바꿀 수 없습니다.

---

## 01. 무음 알림 채널 추가

**수정** — `lib/repository/fcm/fcm_service.dart:32`

현재 채널이 하나뿐입니다 — `warding_high_importance` / `Importance.high`.
그 아래에 무음 채널을 추가하고, `initMessaging`의 `createNotificationChannel(_channel)` 옆에서
같이 생성해주세요.

```dart
/// 알림 잠자기 시간대 발송용. 서버가 무음일 때 이 채널 id 로 보낸다.
/// id 문자열은 서버(FirebaseMobilePushGateway.QUIET_CHANNEL_ID)와 반드시 일치해야 한다.
static const AndroidNotificationChannel _quietChannel = AndroidNotificationChannel(
  'warding_quiet',
  '알림 잠자기',
  description: '잠자기 시간대에 소리 없이 받는 알림',
  importance: Importance.low,
  playSound: false,
  enableVibration: false,
);
```

### 이미 앱을 깐 유저는 채널이 없습니다

채널은 앱이 실행될 때 만들어지므로, 이 버전으로 업데이트한 유저만 `warding_quiet`을 갖습니다.
서버는 잠자기를 켠 유저에게만 이 채널로 보내고, 잠자기는 이 버전 이후에만 켤 수 있으니
구버전 기기는 안전합니다. **추가 버전 체크는 필요 없습니다.**

---

## 02. 포그라운드 표시 경로 분기

**수정** — `lib/repository/fcm/fcm_service.dart:195`

백그라운드에서는 시스템이 payload의 채널대로 표시하니 자동으로 조용해집니다.
**문제는 포그라운드입니다.** Android는 앱이 떠 있을 때 `_showForegroundNotification`이 로컬 알림을
직접 띄우는데, 여기가 `_channel.id`와 `Importance.high`를 하드코딩하고 있어서
**잠자기 시간에도 소리가 납니다.**

서버가 보낸 채널 id를 읽어 분기해주세요. 소리 나는 발송에는 서버가 `AndroidNotification`을
아예 안 붙이므로 `channelId`가 null로 옵니다.

```dart
final quiet = message.notification?.android?.channelId == _quietChannel.id;
final channel = quiet ? _quietChannel : _channel;

await _localNotifications.show(
  id: notification.hashCode,
  title: notification.title,
  body: notification.body,
  notificationDetails: NotificationDetails(
    android: AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: quiet ? Importance.low : Importance.high,
      priority: quiet ? Priority.low : Priority.high,
      playSound: !quiet,
      enableVibration: !quiet,
      icon: '@drawable/ic_stat_warding',
    ),
  ),
  payload: jsonEncode(message.data),
);
```

**iOS** — 이 함수는 `if (!Platform.isAndroid) return;`으로 iOS를 미리 빠져나갑니다.
iOS 무음은 서버가 `interruption-level: passive` + sound 생략으로 처리하니 앱 작업이 없습니다.
포그라운드일 때 소리가 날 수 있는데, 포그라운드면 유저가 깨어 있으니 무해하다고 판단했습니다.

---

## 03. API 연동

| | 파일 |
|---|---|
| 신규 | `lib/model/quiet_hours.dart` — 모델 (fromJson / toJson / copyWith) |
| 신규 | `lib/repository/notification/quiet_hours_repository.dart` — GET · PUT |
| 수정 | `lib/config/api_config.dart` — URL getter 추가 |

### 엔드포인트

| 메서드 | 경로 | 요청 / 응답 |
|---|---|---|
| GET | `/api/mobile/me/quiet-hours` | `{ "enabled": false, "startTime": "01:00", "endTime": "08:00" }` |
| PUT | `/api/mobile/me/quiet-hours` | 요청 본문은 응답과 같은 모양. 응답도 저장된 값을 그대로 돌려줍니다 |

- 시각은 **`"HH:mm"` 문자열**입니다. 초는 없습니다. `TimeOfDay` ↔ 문자열 변환은 앱에서 하면 됩니다.
- 둘 다 **인증 필요**입니다. 기존 `SubscriptionRepository`처럼 `AuthService.authorizedRequest`로
  감싸주세요 — 토큰 만료 시 자동 갱신·재시도가 붙습니다.
- `ApiConfig`에 추가: `static String get quietHoursUrl => '$apiBaseUrl/mobile/me/quiet-hours';`
- PUT 구현은 `SubscriptionRepository.updateTeamNotification`(185행)이 그대로 선례입니다 —
  `jsonEncode` 본문, 상태코드 검사, `SentryLogger`.

### 에러 응답

| 상태 | 언제 | 앱 처리 |
|---|---|---|
| 400 | `enabled=true`인데 시작 == 종료 | "시작과 종료가 같으면 안 됩니다. 다른 시간을 골라주세요." |
| 400 | 분이 5의 배수가 아님 (시작·종료 양쪽 검사) | UI가 5분 스텝이면 발생하지 않습니다. 방어용 |
| 401 | 비로그인 | 카드를 숨기므로 정상 흐름에선 발생하지 않습니다 |

### PUT 본문에서 `enabled`를 빼지 마세요

서버가 `@NotNull`로 막아 400을 돌려줍니다. 부분 업데이트(PATCH 성격)를 지원하지 않으니
**세 필드를 항상 함께** 보내주세요. 토글만 바꿀 때도 현재 시각 값을 같이 실어야 합니다.

---

## 04. 설정 UI

| | 파일 |
|---|---|
| 신규 | `lib/screens/mypage/component/quiet_hours_section.dart` — 섹션 헤더 + 카드 |
| 신규 | `lib/screens/mypage/component/quiet_hours_time_sheet.dart` — 5분 스텝 시각 선택 바텀시트 |
| 신규 | `lib/viewmodel/mypage/quiet_hours_viewmodel.dart` — ChangeNotifier |
| 수정 | `lib/screens/mypage/mypage_screen.dart:190` — 섹션 삽입 |
| 수정 | `lib/l10n/app_ko.arb` · `app_en.arb` — 문구 6개 |

### 배치 — `SubscriptionAlarmSection` **위**

마이페이지에서 `SubscriptionAlarmSection`(191행) **바로 위**, 그 앞의 `SizedBox(height: 20 * scale)`
다음에 넣어주세요. 즉 프로필/응원팀 배너 → **알림 잠자기** → 구독 팀 알림 설정 순서입니다.
`SubscriptionAlarmSection`이 카드 구조·타이포·`NarToggle` 사용법의 선례입니다.

아래에 두면 안 되는 이유 3가지 (처음엔 아래로 제안했다가 정정했습니다):

1. **위계가 거꾸로.** 잠자기는 전역(모든 알림), 팀 알림 설정은 개별(팀별 × 종류별). 전역이 개별 아래 오면 스캔 순서가 어긋납니다.
2. **팀 카드가 가변 높이.** 팀당 헤더 + 토글 3행이라 구독 5팀이면 20행입니다. 그 아래 두면 **발견성이 구독 수에 반비례**합니다 — 알림을 많이 받는 유저(=이 기능이 필요한 유저)일수록 안 보입니다.
3. **"구독 팀 알림 설정" 제목에 붙는 오해.** 잠자기는 솔랭도 포함하는데 팀 알림에만 적용되는 것처럼 읽힙니다.

배치 비교는 목업 1번 섹션에 화면 골격으로 그려뒀습니다.

### 카드

- **OFF** — 토글 1행 + 안내 문구. 시간 행은 숨깁니다.
- **ON** — 구분선(`AppColors.narLine`) 아래 `시작` / `종료` 2행. 각 행 우측은 값 + chevron, 탭하면 시트.
- 팀 알림 행이 쓰는 좌측 들여쓰기(`EdgeInsets.fromLTRB(60, …)`)는 **쓰지 마세요.**
  그건 팀 로고 정렬용이고 여기엔 로고가 없습니다. 좌우 20으로 맞춰주세요.
- **비회원은 카드를 숨깁니다.** `subscription_alarm_section.dart:53`의
  `if (!_viewModel.loggedIn) return const SizedBox.shrink();` 패턴과 동일하게요.

### 시각 선택 시트

`showTimePicker`가 코드는 적지만 앱이 바텀시트로 톤을 통일해 뒀어서 머티리얼 다이얼로그 하나가 튑니다.
**5분 스텝이면 분 휠이 12행뿐**이라 조립 비용이 거의 없습니다.

- `showAppBottomSheet`로 띄우고, `language_setting_sheet.dart`의 드래그 핸들 + 타이틀 구조를
  따라주세요 (하단 `showXSheet` 최상위 함수 패턴 포함).
- 휠은 `CupertinoPicker` 3열(오전·오후 / 시 / 분) 또는 `ListWheelScrollView`.
  분은 `00, 05, … 55` 12개.
- 하단에 취소 / 저장. 저장이 `AppColors.narBg` 그라데이션.

### 문구 (ko / en 양쪽 필요)

| 위치 | 한국어 | English |
|---|---|---|
| 섹션 제목 | 알림 잠자기 | Quiet hours |
| 토글 | 잠자기 사용 | Use quiet hours |
| 시간 라벨 | 시작 · 종료 | From · To |
| OFF 안내 | 사용하면 정한 시간엔 알림이 소리 없이 알림함에만 쌓입니다. | When enabled, notifications arrive silently and stay in your inbox. |
| ON 안내 | 오전 1:00부터 오전 8:00까지 모든 알림이 소리 없이 알림함에만 쌓입니다. | From 1:00 AM to 8:00 AM, all notifications arrive silently and stay in your inbox. |
| 오류 | 시작과 종료가 같으면 안 됩니다. 다른 시간을 골라주세요. | Start and end can't be the same. Pick a different time. |

**ON 안내에 실제 설정 시각을 넣어주세요.** "무음으로 쌓인다"는 동작이 눈에 보이지 않아 유저가
잠자기를 껐다고 착각하기 쉽습니다.

---

## 05. 확인

### 실기기 확인 시 주의 — 로컬에서 테스트 푸시를 쏘지 마세요

로컬 환경이 FCM 자격증명을 프로덕션과 공유합니다. 로컬에서 발송을 트리거하면
**실제 유저에게 알림이 갈 수 있습니다.** 백오피스에 "내 기기 토큰만 지정해 쏘는" 트리거가
아직 없어서(백엔드 후속 과제), 그게 준비되기 전에는 실기기 무음 확인을 미뤄주세요.
채널 생성 자체와 UI·API는 그것 없이도 확인 가능합니다.

### 앱만으로 확인 가능한 것

- Android 시스템 설정 → 앱 알림에 **"알림 잠자기" 채널이 새로 보이는지.** 안 보이면 채널 생성이 안 된 것입니다.
- 설정 저장 → 앱 재시작 → GET으로 값이 그대로 돌아오는지.
- 시작 == 종료로 저장 시 400을 받아 오류 문구가 뜨는지.
- 비로그인 상태에서 카드가 안 보이는지.
- 자정 넘김(예: 23:00 ~ 08:00) 저장이 되는지. 판정은 서버가 하니 앱은 저장·표시만 확인하면 됩니다.

### 백엔드 쪽 참고 (이미 완료)

- 테스트 545건 통과. 판정 로직·2그룹 분할 발송·게이트웨이 무음 분기 전부 회귀 가드 있음.
- 죽은 `all_solo_rank` FCM 토픽 발송을 삭제했습니다. 앱에 `subscribeToTopic` 호출이 없어
  아무도 받지 않던 코드였습니다 — 혹시 앱에 토픽 구독을 새로 넣을 계획이 있으면 알려주세요.
- 발송 시 서버가 회원을 "잠자기 걸림 / 안 걸림" 두 그룹으로 나눠 멀티캐스트를 최대 2회 보냅니다.
  앱은 받은 채널 id만 보면 됩니다.

---

## 순서 제안

1. **01 + 02 먼저** (채널 + 포그라운드 분기). 이게 Android 무음의 전부이고,
   스토어 심사·업데이트 확산이 크리티컬 패스라 먼저 나가는 게 좋습니다.
2. **03 + 04** (API + UI). 백엔드 브랜치가 머지·배포된 뒤 붙이면 됩니다.

01~02만 배포해도 유저에겐 아무 변화가 없습니다(잠자기를 켤 UI가 없으니 서버가 무음으로 보낼 일이 없음).
그래서 두 단계로 나눠 내보내도 안전합니다.
