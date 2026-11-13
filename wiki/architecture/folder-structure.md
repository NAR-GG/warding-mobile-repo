---
type: Architecture Reference
title: 폴더 구조
description: lib/ 하위 디렉토리별 역할 정의. feature 단위 구조.
resource: https://github.com/NAR-GG/warding-mobile-repo/tree/main/lib
tags: [architecture, structure]
timestamp: 2026-11-10T00:00:00Z
---

# lib/ 구조

**feature 단위 구조다.** 기능별로 `data`·`domain`·`presentation` 세 레이어를 한 폴더에
모은다. 이전에는 레이어가 최상위 축이어서 한 기능을 작업할 때 네 군데
(`model`·`repository`·`viewmodel`·`screens`)를 오가야 했다.

```
lib/
├── features/     기능별 27개
│   └── {기능}/
│       ├── data/           repository, API 예외, 그 기능 전용 DTO
│       ├── domain/         모델, 규칙·상수
│       └── presentation/
│           ├── screens/    화면 (멀티스텝은 step/, guide 는 page/)
│           ├── viewmodels/ ViewModel
│           └── widgets/    그 화면 전용 위젯
├── app/          앱 셸 — 모든 기능을 알아도 되는 코드 (딥링크·탭 이동·훅 연결) 7개
├── domain/       여러 기능이 쓰는 모델 10개 + repository 인터페이스 2개
├── core/         기능 소유가 아닌 기술 인프라
│   ├── infrastructure/     여러 기능이 쓰는 서비스·repository 19개
│   ├── ui/                 앱 전역 공용 위젯 52개
│   ├── theme/              디자인 토큰 (app_colors 등)
│   ├── config/             앱 설정 (API URL, 키 등)
│   ├── error/              Failure 계층, FailureException
│   ├── usecase/            UseCase 기반 타입
│   ├── data/               예외 → Failure 매퍼
│   └── util/               유틸리티 21개
├── l10n/         생성물 (아래 예외 참고)
├── main.dart     진입점
└── firebase_options.dart   생성물
```

# domain 이 최상위인 이유

**도메인 모델은 기술 인프라 안에 종속되지 않는다.** 처음에는 `core/domain/` 이었는데, 그러면
"도메인이 `core` 의 하위 개념"으로 읽힌다. Clean Architecture 원전
([Robert C. Martin, 2012](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html))
에서 도메인은 가장 안쪽 원이고 아무것도 참조하지 않는 중심이다.

실제 앱 5개를 조사한 결과 **4개가 공유 도메인 모델을 최상위 공유 위치에 둔다.**

| 레포 | 공유 모델 위치 | 예 |
|---|---|---|
| nowinandroid (Google 공식) | `core/model/` 모듈 | NewsResource, Topic |
| compass_app (Flutter 공식) | `lib/domain/models/` | Destination, ItineraryConfig |
| Immich | `lib/domain/models/` | Asset, Album, Person |
| LocalSend | `lib/model/` + 별도 패키지 | Device, FileDto |
| AppFlowy | `features/share_tab/data/models/` (유일한 예외) | ShareAccessLevel |

**"공유 위치는 도메인 중립이어야 한다"를 지키는 레포는 0/5 다.** `core:model` 에
`NewsResource` 가, `domain/models/` 에 `Asset` 이 그냥 들어간다. 그래서 `schedule_match` 처럼
명백한 e스포츠 도메인 개념이 `domain/` 에 있는 것이 정상이다.

**compass_app 의 `ItineraryConfig` 가 판단 기준의 교과서다.** 5개 화면 중 4개가 쓰는 모델인데
가장 소유자처럼 보이는 `search_form` 안에 두지 않고 `domain/models/` 로 올렸다 — Flutter 공식
샘플이 "여러 기능이 쓰면 올린다"를 명시적으로 선택한 지점이다.

**`domain/` 은 `core/` 조차 import 하지 않는다.** 모델이 인프라를 알면 방향이 뒤집힌다.
현재 `l10n`(생성물) 외 참조 0건.

반대로 **인프라 서비스는 5/5 전원 공유 위치**다 — AppFlowy 조차 모델은 feature 에 두면서
auth 는 `user/application/auth/` 로 뺐다. 그래서 `core/infrastructure/auth` 는 19개 기능이
쓰더라도 `features/auth/` 로 내리지 않는다.

**규칙은 한 문장이다 — 기능 소유면 `features/`, 아니면 `core/`.** 처음에는 `components`·
`styles`·`config`·`util` 을 최상위에 뒀는데, 그러면 `core/` 에 들어간 `team`(2곳에서 사용)
보다 더 광범위하게 공유되는 것들(`styles` 27곳, `components` 25곳, `util` 22곳,
`config` 16곳)이 밖에 남아 기준이 어긋났다.

# 의존 방향: app → features → core

`core/` 는 `features/`·`app/` 을 import 하지 않는다. 유일한 예외는 조립 지점인
`core/di_container.dart` 로, repository 구현체를 등록하느라 24개 기능 파일을 안다.

2026-11-10 점검에서 `core` 가 `features` 를 거꾸로 참조하는 곳이 66건(DI 24 + 42)
나왔고, 전부 풀었다. 푸는 방법은 세 가지였다.

| 상황 | 해법 | 예 |
|---|---|---|
| 앱 셸 코드 (모든 기능을 알아야 한다) | `lib/app/` 로 이동 | `fcm_service`, `home_widget_service`, `live_match_activity_controller`, `live_activity_logo_prefetcher`, `match_detail_router`, `nav_tab_navigation` |
| 한 기능 전용 위젯·모델이 core 에 있었다 | 그 기능으로 이동 | `guide_popup`→`guide`, `cheer_ad_popup`·`cheer_ad_banner`→`cheer_ad`, `notification_feed_card`→`subscription`, `guest_lock_overlay`→`login`, `solo_hero_card`→`home`, `advertiser_banner`→`notice`, `league_meta`·`league_icon`→`schedule`, `onboarding_preference_repository`→`onboarding` |
| core 가 기능의 화면·구현이 필요하다 | core 에 훅 자리를 두고 `app/app_hooks.dart` 에서 채운다 | `AuthService.loginScreenBuilder`, `AuthService.onSignedOut`, `TeamLogoDirectory.defaultLoader` |

반대로 `features` 가 소유하던 것이 사실은 공용이라 `core` 로 올린 것도 있다:
`quiet_hours`(→`domain`), `team_logo_directory`(→`core/infrastructure/team`),
`parseServerTime`(→`core/util/server_time.dart`).

# core 밖에 남는 예외

**생성물과 진입점.** 생성물은 생성 도구가 경로를 정하므로, 옮겨도 도구가 원래 자리에 다시
만들어 두 벌이 생긴다.

| 대상 | 경로를 못박는 설정 |
|---|---|
| `lib/l10n/` | `l10n.yaml` 의 `arb-dir`·`output-dir` |
| `lib/firebase_options.dart` | `firebase.json` 의 `flutter.platforms.dart` 키 |
| `lib/main.dart` | 진입점 |
| `lib/app/` | 앱 셸. 의존 방향상 `core` 밖이어야 한다 (위 절) |

옮기려면 그 설정부터 바꿔야 하는데 이득이 없다. 특히 `firebase.json` 은 FlutterFire CLI 가
관리하는 파일이라 손으로 고치면 다음 `flutterfire configure` 에 덮일 수 있다.

# core 에 있는 것

| 대상 | 기능 소비처 수 |
|---|---|
| `auth` | 18 |
| `preference` | 8 |
| `notification` | 4 |
| `fcm`, `ad`, `live_activity` | 2~3 |
| `device` | 0 (`auth_service`·`fcm_service` 만 씀) |

`domain/` 에는 모델 10개 + repository 인터페이스 2개 — `schedule_match`(6곳), `team`(6곳),
`player_subscription`(5곳), `user_profile`(2곳), `member_notification`(2곳),
`team_notification_subscription`(2곳), `calendar_week_start`(2곳), `quiet_hours`(1곳),
`live_match_notification`·`solo_rank_notification`(기능 소비처 0, core store 전용).

# 소유자 판단 기준

**소비처를 세서 정한다.** 세는 규칙:

- **`core/` 안에서의 참조는 세지 않는다.** core 끼리 쓰는 건 당연하다. `device` 는 기능
  소비처가 0 이고 인프라끼리만 쓰므로 `core/` 가 맞다. `live_match_notification`·
  `solo_rank_notification` 모델도 같은 이유로 자기 store 옆(`domain`)에 있다.
- **이름이 같은 기능이 있으면 그 기능 소유로 본다.** `rating` repository 는 4곳이 쓰지만
  `player_rating` 기능이 있어 `features/player_rating/data/` 에 둔다.
- **`home` 은 소비처로 세지 않는다.** 집계 화면이라 거의 모든 기능을 당겨서, 세면
  repository 대부분이 `core/` 로 가 버린다.
- 소비처가 1곳이면 그 기능으로 내린다 — `team` repository(`home` 만),
  `onboarding_selection`(`onboarding` 만). 단 repository 가 `core/` 에 있는 모델은 `domain` 에
  둔다 — `quiet_hours` 는 `mypage` 만 쓰지만 `core` 의 repository 가 쓴다.
- 소유자가 둘이고 어느 쪽도 주 소유가 아니면 `core/` — `user_profile`(`mypage`·
  `profile_edit`).

# presentation 만 있는 기능이 많은 이유

27개 중 13개는 `data/`·`domain/` 이 비어 있다. 억지로 만들지 않는다.

- **데이터가 공용이라서** — `mypage` 는 `domain/user_profile`,
  `my_subscription_setting` 은 `domain/player_subscription` 을 쓴다. 한 기능 소유가
  아니니 `core/` 가 맞고, 그 기능 폴더가 비는 것이 정상이다.
- **애초에 자기 데이터가 없어서** — `login`·`withdraw`·`account_setting`·`splash`·`guide`·
  `cheer_ad` 는 설정·플로우·안내 화면이라 공용 서비스만 호출한다. `guide` 11개 파일은 전부
  페이지 위젯이다.

빈 폴더는 구조가 아니라 소음이다. 필요할 때 만든다.

# import 규칙

**`package:warding/...` 절대경로로 쓴다.** 상대경로(`../../model/...`)는 파일을 옮길 때
대량으로 깨진다 — 이 전환에서 540건이 났다. `export` 도 마찬가지다(`export '../../../util/
shorts_url.dart'` 하나가 테스트 10건을 깨뜨렸다).

# 비고

- `data` 와 `domain` 의 구분: `domain`은 그 기능의 개념(모델·규칙·상수), `data`는 그것을
  가져오는 수단(repository·API 예외)과 그 기능 전용 DTO다. `community_permission.dart`처럼
  화면이 아닌 규칙 파일은 `screens`가 아니라 `domain`에 둔다.
- 한 기능 소유가 아닌 것을 `features/` 안에 두면 다른 기능이 남의 폴더를 들여다봐야 한다.
  쓰는 기능이 둘 이상이면 `core/` 후보다.
- 한 화면에서만 쓰는 위젯은 그 기능의 `presentation/widgets/`에, 여러 기능에서 쓰면
  `core/ui/`에 둔다.
- 디자인 토큰은 `core/theme/`에 모은다 → [색상 토큰](/design/color-tokens.md).
- 계층별 책임은 [MVVM 패턴](/architecture/mvvm.md), 새 파일 위치는
  [파일 생성 규칙](/architecture/file-conventions.md) 참조.
- 상태 관리는 `ChangeNotifier` 기반 MVVM 을 유지한다. `presentation/`은 BLoC 을 전제한
  이름이지만, 지금은 ViewModel 이 그 자리에 있다 — 나중에 상태 관리를 바꿀 때 폴더는
  그대로 쓸 수 있다.

# Citations

[1] [CLAUDE.md — 폴더 구조](../../CLAUDE.md)
[2] [웹뷰 전환 Spec — 레포 배치](../../intent/hybrid-webview-monorepo/spec.md)
