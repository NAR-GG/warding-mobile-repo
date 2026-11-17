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
├── features/     기능별 32개
│   └── {기능}/
│       ├── data/           repository, API 예외, 그 기능 전용 DTO
│       ├── domain/         모델, 규칙·상수
│       └── presentation/
│           ├── screens/    화면 (멀티스텝은 step/, guide 는 page/)
│           ├── viewmodels/ ViewModel
│           └── widgets/    그 화면 전용 위젯
├── app/          앱 셸 — 기능 2개 이상의 화면·구현을 알아야 하는 코드 5개
│   ├── deeplink/           푸시·홈 위젯 → 앱 진입
│   ├── navigation/         경기 상세 창구, 탭 전환
│   ├── di_container.dart   인터페이스 ↔ 구현 등록 (기능 12개를 안다)
│   └── app_hooks.dart      core 에 비워 둔 자리를 채우는 조립
├── core/         기술만 — 도메인 개념이 없다 (75파일)
│   ├── ui/                 앱 전역 공용 위젯 48개
│   ├── util/               순수 함수·포맷터 17개
│   ├── config/             앱 설정 (API URL, 키 등) 5개
│   ├── error/              Failure 계층, API 상태 예외 3개
│   ├── theme/              디자인 토큰 (app_colors)
│   └── data/               예외 → Failure 매퍼
├── l10n/         생성물 (아래 예외 참고)
├── main.dart     진입점
└── firebase_options.dart   생성물
```

# core 에 도메인 개념을 두지 않는다

**소비처가 몇 곳이든 "경기·팀·선수·알림·인증" 같은 이름이 붙으면 그 도메인의 기능으로
간다.** 2026-11-16 에 `core/domain/`(모델 9) 과 `core/infrastructure/`(21파일) 를 전부
해체했다.

해체 전에는 "소비처를 세서 2곳 이상이면 `core`" 였는데, 그 규칙이 `core` 안을 도메인으로
채웠다 — 폴더 이름뿐 아니라 내용도 그랬다. `notification/` 에 마이구독 알림 피드 API 와
알림 잠자기 설정이, `live_activity/` 에 실시간 경기 카드 제어가, `preference/` 에 선호 팀
저장과 스포방지 설정이 있었다.

| 원래 위치 | 간 곳 | 판단 |
|---|---|---|
| `infrastructure/auth` + `device` + `domain/user_profile` | `features/auth/` | 상호 참조라 한 묶음(auth→device 1건, device→auth 2건). 20개 기능이 쓰지만 인증은 도메인이다 |
| `infrastructure/notification` 4 + 모델 4 + 인터페이스 2 + `fcm_notification_types` | `features/notification/` | 알림 도메인 |
| `infrastructure/live_activity` 4 | `features/live_activity/` | 실시간 카드 도메인. 2026-11-13 에 `app/` 에서 `core/` 로 내렸던 둘이 여기로 왔다 |
| `infrastructure/preference` 7 + `ad` | 각 소유 기능 | cheer_ad·guide·calendar_setting·notice·match_list_setting·schedule·onboarding |
| `domain/` 모델 4 | 각 소유 기능 | schedule_match→schedule, team→onboarding, calendar_week_start→calendar_setting, team_notification_subscription→subscription |

**`core` 에 남는 것은 기술뿐이다** — `ui`(48) · `util`(17) · `config`(5) · `error`(3) ·
`theme`(1) · `data`(1). 114 → 75파일.

## core 에 남아도 되는 도메인 이름

- **순수 함수·포맷터는 `core/util/`.** `match_status(String)` 는 문자열 판정이고
  `rating_mapping` 은 수치 변환이다 — 모델도 repository 도 없어서 성격이 다르다. 단
  1기능만 쓰면 내린다(`dragon_type`·`gold_format`·`live_elapsed`·`standings_group_label`
  이 그렇게 갔다).
- **공용 위젯은 `core/ui/`.** `team_logo`·`team_code_badge` 는 "팀 로고를 그리는 위젯"이고
  `team_logo_directory` 는 그 위젯이 쓰는 URL 캐시다. `core/ui` 위젯 2개가 참조한다.
- **`api_status_exception` 은 `core/error/`.** HTTP 상태코드 예외라 기술이고,
  `failure_mapper` 가 그걸 `Failure` 로 바꾼다.

## 조사한 레포와의 차이

조사한 실제 앱 5개는 **인프라를 공유 위치에 둔다(5/5)** — AppFlowy 조차 모델은 feature 에
두면서 auth 는 `user/application/auth/` 로 뺐다. 여기서는 그 관행을 따르지 않고 "core 에
도메인 이름이 없어야 한다"를 우선했다.

대가는 `features/auth/` 가 20개 기능이 참조하는 기능이 된 것이다. 그게 사실상 공유 코드와
같은 역할이지만, **적어도 `core` 를 열었을 때 경기·팀·알림이 보이지 않는다.** 어느 쪽이
나은지는 취향이 갈리는 지점이고, 이 레포는 후자를 골랐다.

**`core` → `features`·`app` 참조 0건.** `di_container` 를 `app/` 으로 옮겨 마지막 예외도
없앴다(조사한 레포 4개 전부 DI 를 앱 셸에 둔다 — nowinandroid `app/di/`, compass_app
`lib/config/dependencies.dart`, Immich `lib/providers/`, AppFlowy
`lib/startup/deps_resolver.dart`).

**규칙은 한 문장이다 — 기능 소유면 `features/`, 아니면 `core/`.** 처음에는 `components`·
`styles`·`config`·`util` 을 최상위에 뒀는데, 그러면 `core/` 에 들어간 `team`(2곳에서 사용)
보다 더 광범위하게 공유되는 것들(`styles` 27곳, `components` 25곳, `util` 22곳,
`config` 16곳)이 밖에 남아 기준이 어긋났다.

# Entity 레벨은 어디인가

Clean Architecture 원전의 가장 안쪽 원(Entities)에 해당하는 자리는 **두 곳**이다.

**`features/{기능}/domain/`** 한 곳이다 — 2026-11-16 에 `core/domain/` 을 해체해서
공유 모델도 각 소유 기능으로 갔다. 모델 약 50개 + repository 인터페이스 15개.

**그런데 46개 중 실제 비즈니스 규칙을 가진 것은 5개뿐이다.** 나머지는 "필드 +
`fromJson` + `copyWith`" 로, 엄밀히는 Entity 가 아니라 DTO 에 가깝다.

| 파일 | 규칙 |
|---|---|
| `features/solo_rank/domain/solo_rank_rules.dart` | 솔랭 선수를 진행/종료로 분류, 정렬 순서, 구독 필터 |
| `features/community/domain/community_permission.dart` | `canWriteToBoard` — 비로그인 금지, 전체 게시판 허용, 팀 게시판은 내 팀만 |
| `features/community/domain/community_rules.dart` | 이용규칙 본문 + 버전(`2026.08`) |
| `features/calendar_setting/domain/calendar_week_start.dart` | `leadingDays`·`weekCount`·`orderedWeekdayLabels` — 달력 격자 계산 |
| `features/notification/domain/quiet_hours.dart` | `isSameTime` — 시작=종료면 24시간 |

**그게 정상이다. 이 앱의 비즈니스 규칙 대부분이 백엔드에 있다.** 경기 상태 판정·평점 집계·
구독 처리가 전부 API 다. 클라이언트에 남는 규칙은 **표시 방식**(달력 격자, 솔랭 정렬)과
**권한 판정**(글쓰기)이라, Entity 가 얇은 것이 구조 결함이 아니다. UseCase 가 1개뿐인
([`GetPreferredTeam`](../../lib/features/home/domain/usecases/get_preferred_team.dart))
것도 같은 이유다 — 나머지는 repository 1개 호출이라 빼면 빈 껍데기가 된다.

`member_notification` 의 getter 13개는 규칙처럼 보이지만 payload 접근자(`_d('playerName')`)다.

**Entity 레벨의 역방향 참조는 0건이다.** `features/*/domain` → `data`·`presentation`·`app`
전부 0. 2026-11-16 점검에서 한 건(`solo_rank_rules` → `data/solo_rank_sources`)이 나와
모델·계약을 `domain/` 으로 올렸다.

**예외 1건: `features/notification/domain/quiet_hours.dart` 가 `TimeOfDay` 를 쓴다.** 원전대로면 Entity 가 UI
프레임워크를 몰라야 하지만, 자체 Time 타입을 만들면 화면마다 변환이 붙는다. `TimeOfDay` 는
위젯이 아닌 값 타입이라 그대로 둔다.

# 의존 방향: app → features → core

**`core/` 는 `features/`·`app/` 을 import 하지 않는다 — 예외 0건.** 조립 지점인
`di_container.dart` 가 기능 12개의 repository 를 알아야 해서 `app/` 에 있다.

2026-11-10 점검에서 `core` 가 `features` 를 거꾸로 참조하는 곳이 66건(DI 24 + 42)
나왔고, 전부 풀었다. 푸는 방법은 세 가지였다.

| 상황 | 해법 | 예 |
|---|---|---|
| 앱 셸 코드 (기능 2개 이상의 화면을 안다) | `lib/app/` 로 이동 | `fcm_service`, `home_widget_service`, `match_detail_router`, `tab_navigation` |
| 기능 repository 만 쓰고 화면은 안 띄운다 | 그 도메인의 기능으로 | `live_activity_logo_prefetcher`, `live_match_activity_controller` → `features/live_activity/data/` (2026-11-13 `core` 로, 11-16 기능으로 재분류) |
| 한 기능 전용 위젯·모델이 core 에 있었다 | 그 기능으로 이동 | `guide_popup`→`guide`, `cheer_ad_popup`·`cheer_ad_banner`→`cheer_ad`, `notification_feed_card`→`subscription`, `guest_lock_overlay`→`login`, `solo_hero_card`→`home`, `advertiser_banner`→`notice`, `league_meta`·`league_icon`→`schedule`, `onboarding_preference_repository`→`onboarding` |
| core 가 기능의 화면·구현이 필요하다 | core 에 훅 자리를 두고 `app/app_hooks.dart` 에서 채운다 | `AuthService.loginScreenBuilder`·`onSignedOut`, `TeamLogoDirectory.defaultLoader`, `LiveActivityLogoPrefetcher.teamTargetsLoader`, `LiveMatchActivityController` 의 로더 4개 |

반대로 `features` 가 소유하던 것이 사실은 기술이라 `core` 로 올린 것도 있다:
`team_logo_directory`(→`core/ui/`, 공용 위젯 2개가 쓴다),
`parseServerTime`·`minutesSince`(→`core/util/server_time.dart`).

# app/ 과 core/ui/ 는 왜 다른 자리인가

**둘은 의존 방향이 반대다.** 공용 컴포넌트는 아무것도 모르고 많이 쓰이며, 앱 셸은 많이 알고
적게 쓰인다.

| 대상 | 쓰는 곳 | 아는 기능 |
|---|---|---|
| `core/theme/app_colors` | 142파일 | 0개 |
| `core/ui/nar_card` | 6파일 | 0개 |
| `app/navigation/tab_navigation` | 4파일 | **6개** |
| `app/app_hooks` | 2파일 | **3개** |

`core/ui` 48개는 현재 `features`·`app` 참조가 **전부 0건**이다. 거기에 앱 셸 코드를
섞으면 `core` 가 기능을 알게 되어 의존 방향이 무너진다.

**탭 네비게이션은 "위젯"과 "목적지"가 이미 갈려 있다.** 하단 바를 그리는 `AppBottomNav` 와
`AppNavTab` enum 은 `core/ui/app_bottom_nav.dart`(기능 0개)에 있고, 그 탭이 어느 화면으로
가는지는 `app/navigation/tab_navigation.dart`(기능 6개)가 안다. nowinandroid 도 같다 —
위젯은 `core:designsystem/component/Navigation.kt`, 목적지 목록은
`app/navigation/TopLevelNavItem.kt` 다.

실제 앱 4개를 조사한 결과 **공용 UI 와 앱 셸을 같은 위치에 두는 레포는 0개**였다.

| 레포 | 공용 UI | 앱 셸(라우팅·DI) |
|---|---|---|
| nowinandroid | `core/designsystem/`, `core/ui/` | `app/` 모듈 |
| compass_app | `lib/ui/core/` | `lib/routing/`, `lib/config/` |
| Immich | `packages/ui/`, `lib/widgets/` | `lib/routing/`, `lib/providers/` |
| AppFlowy | `packages/appflowy_ui/` | `lib/startup/` |

**여러 기능 화면을 직접 아는 코드(라우터·탭)는 4/4 전부 앱 셸에 있다.** compass_app
`routing/router.dart` 는 화면 12개를, Immich 는 70개 이상을, AppFlowy
`startup/tasks/generate_router.dart` 는 20개 이상을 직접 import 한다.

**공용 폴더가 오염된 레포도 있었고, 둘 다 그걸 부채로 보고 있다.** AppFlowy `lib/shared/` 는
`plugins/`·`workspace/` 의 화면과 DI 로케이터까지 import 하고, Immich
`lib/widgets/common/` 은 `pages/common/settings.page.dart` 와 `routing/router.dart` 를
끌어온다. 두 레포 모두 나중에 feature 의존 0건인 순수 패키지(`appflowy_ui`, `immich_ui`)를
추가해 거기로 옮겨가는 중이다. 역참조가 생긴 쪽은 전부 "앱 패키지 안의 공용 폴더"였고,
깨끗한 쪽은 별도 빌드 단위였다.

**그래서 다음 개선은 빌드 단위 격리다.** 4개 중 3개가 디자인 시스템을 Gradle 모듈 또는 Dart
패키지로 떼어내 역참조를 컴파일 에러로 막는다. 지금은 폴더 분리뿐이라 컨벤션에 의존한다 —
웹뷰 전환에서 모노레포를 도입할 때 `packages/` 로 빼는 것이 자연스럽다
([웹뷰 전환 Spec](../../intent/hybrid-webview-monorepo/spec.md)의 토큰 패키지 계획 참고).

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

# 소유자 판단 기준

**"어느 도메인인가" 가 먼저고 소비처 수는 그다음이다.** 2026-11-16 전에는 순서가 반대여서
(소비처 2곳 이상 → `core`) `core` 안이 도메인으로 찼다.

- **도메인 이름이 붙으면 그 기능이다.** 소비처가 20곳이어도 마찬가지 —
  `auth_service` 가 `features/auth/` 에 있는 이유다.
- **이름이 같은 기능이 있으면 그 기능 소유.** `rating` repository 는 4곳이 쓰지만
  `player_rating` 기능이 있어 `features/player_rating/data/` 에 둔다.
- **`home` 은 소비처로 세지 않는다.** 집계 화면이라 거의 모든 기능을 당겨서, 세면
  대부분이 공유 위치로 가 버린다.
- 여러 기능이 쓰는데 주 소유가 애매하면 **가장 본질적으로 쓰는 쪽**이다 —
  `filter_preference` 는 match_list·schedule·splash 가 쓰지만 필터를 정의하는 곳이
  `schedule` 이라 그쪽이다. 다른 기능이 참조하는 것은 허용한다.
- **상호 참조하는 것은 한 묶음으로 옮긴다.** `auth_service` ↔ `device_repository` 가
  서로를 참조해서(1건·2건) 함께 `features/auth/` 로 갔다.
- **집계 화면 안에 다른 기능이 쓰는 코드가 들어 있으면 독립 기능으로 뺀다.** `home` 은
  소비처로 세지 않는다는 규칙이 반대로 작용해, 솔랭 코드가 `features/home/` 에 쌓여
  있었다. `player`·`my_players` 가 그걸 17곳에서 당겨 써서 남의 폴더를 들여다보던
  상태였다 — `features/solo_rank/` 로 올려 0건으로 만들었다. 판단은 "홈이 만든 코드인가"
  가 아니라 "홈 밖에서도 쓰는가"다.

# 집계 화면은 섹션을 조합만 한다

**홈처럼 여러 기능을 모아 보여주는 화면은 각 섹션을 직접 구현하지 않는다.** 섹션 로직은 그
기능이 갖고, 집계 화면은 그 ViewModel 을 구독해 배치만 한다.

2026-11-13 점검에서 홈 ViewModel 이 1141줄로, 섹션 9개를 직접 들고 있었다. 그중 7개는 이미
대응 기능이 있는데도 홈이 그 repository 를 직접 부르고 상태를 자기가 들고 있어서, 다른
화면에서 같은 섹션을 쓸 수가 없었다. 전부 각 기능으로 내렸다.

| 홈 섹션 | 옮긴 곳 |
|---|---|
| 커뮤니티 글 | `features/community/.../community_summary_viewmodel` |
| 뉴스 | `features/news/.../news_viewmodel` (기능 신설) |
| 평점 한줄평 | `features/player_rating/.../review_summary_viewmodel` |
| 공지 배너 | `features/notice/.../notice_banner_viewmodel` |
| 벨 배지 | `features/notification/.../notification_badge_viewmodel` |
| 오늘 경기 | `features/schedule/.../today_matches_viewmodel` |
| 구독 선수 | `features/subscription/.../subscribed_players_viewmodel` |
| 솔랭·월즈 | `features/solo_rank/.../solo_rank_viewmodel` |
| 쇼츠 | `features/shorts/.../shorts_summary_viewmodel` |
| 순위표 | `features/standings/.../standings_viewmodel` |

홈은 getter 위임만 남아 **1141 → 469줄**이 됐고, **직접 쓰는 repository·소스가 0개**다.
테스트는 897 → 965 로 늘었다 — 섹션 로직이 홈 안에 묶여 있어 검증할 수
없던 규칙들을 각 VM 에 붙였다.

지킨 규칙 네 가지.

- **전체 화면 VM 과 요약 섹션 VM 을 합치지 않는다.** 요청 모양이 다르다 — 커뮤니티 목록은
  `boardTeamId` 필터와 cursor 페이지네이션, 요약은 `size`·`sort` 로 최신 몇 건. 한 클래스에
  두 역할을 넣으면 홈이 비대했던 문제가 그 기능으로 옮겨갈 뿐이다.
- **섹션 VM 생성자는 조회하지 않는다.** 첫 로드 시점은 쓰는 쪽이 `load()` 로 정한다. 홈처럼
  여러 섹션을 한 번에 당기는 화면이 자기 갱신 주기를 가져야 한다. 생성자에서 조회하게 했다가
  "refreshAll 은 섹션들을 다시 조회한다" 테스트가 중복 호출을 잡았다.
- **섹션 간 의존은 숨기지 않고 주입한다.** 솔랭 카드는 "구독한 선수의 솔랭"이라 구독 목록
  없이 성립하지 않는다 — `SoloRankViewModel(subscriptions: ...)` 로 받고, 구독 목록이 늦게
  도착하면 리스너로 분류를 다시 계산한다. 공유 모델(`PlayerSubscription`)이 `domain/` 에
  있어서 기능 간 결합이 모델까지 번지지 않는다.
- **섹션 위젯은 집계 화면에 남긴다.** `HomeSectionHeader`·`HomeListBox`·`HomeListSkeleton` 은
  홈 레이아웃 부품이고 섹션 6개가 함께 쓴다. 재사용의 핵심은 데이터 로딩·상태 규칙이고,
  레이아웃은 화면마다 다르게 그리는 것이 정상이다.

기존 위젯·테스트가 쓰던 이름은 홈의 getter 위임과 `typedef` 로 유지했다(`HomeCommunitySort`
→ `CommunitySummarySort` 등). 그래서 이 전환에서 화면·위젯 수정은 거의 없었다.

# presentation 만 있는 기능이 많은 이유

32개 중 7개는 `data/`·`domain/` 이 비어 있다. 억지로 만들지 않는다.

- **데이터가 공용이라서** — `mypage` 는 `domain/user_profile`,
  `my_subscription_setting` 은 `domain/player_subscription` 을 쓴다. 한 기능 소유가
  아니니 `core/` 가 맞고, 그 기능 폴더가 비는 것이 정상이다.
- **애초에 자기 데이터가 없어서** — `login`·`withdraw`·`account_setting`·`splash`·`guide`·
  `cheer_ad` 는 설정·플로우·안내 화면이라 공용 서비스만 호출한다. `guide` 11개 파일은 전부
  페이지 위젯이다.

빈 폴더는 구조가 아니라 소음이다. 필요할 때 만든다.

# 우아한형제들 글과의 격차

구조의 출발점은 [우아한형제들 기술블로그 24337](https://techblog.woowahan.com/24337/) 이다.
7개 규칙 중 4개는 따르고 3개는 의도적으로 다르게 간다.

| 글의 규칙 | 지금 | |
|---|---|---|
| repository 인터페이스/구현 분리 | Interface 15 / Impl 12 | ✅ |
| `Either` + sealed `Failure` | repository 28개가 `Either<Failure, T>` | ✅ |
| `di_container.dart` | `lib/app/di_container.dart` | ✅ |
| `fetch{Data}` 네이밍 | fetch 20 / 비-fetch 2 | ✅ |
| **BLoC + Event/State** | `ChangeNotifier` 41개, Bloc 0개 | ❌ |
| **비즈니스 로직은 UseCase** | UseCase 구현체 1개 | ❌ |
| **DTO → Entity → UI State** | DTO 분리 3기능 / 나머지는 Entity 가 `fromJson` | ❌ |

**BLoC 을 안 쓰는 이유.** Flutter 공식 가이드가 `ChangeNotifier` 를 권하고
([docs.flutter.dev/app-architecture](https://docs.flutter.dev/app-architecture)), Mixpanel
이 이미 있어 BLoC 의 이벤트 추적 이점이 중복이다. 실측으로 `notifyListeners` 가 VM 당
평균 1.4회(최대 6회)라 상태 전이가 단순하다 — BLoC 이 이기는 조건(같은 이벤트가 상태에
따라 다르게 동작)에 해당하는 화면이 없다. 폴더명은 `presentation/` 그대로 둬서 나중에
바꿀 때 이동이 없다.

**UseCase 가 1개인 이유.** 뺄 가치가 있는 것이 실측으로 1개였다 — `GetPreferredTeam` 은
repository 3개를 조합하고 폴백 순서(서버 우선 → 로컬 캐시)가 규칙이다. 홈의 섹션 로더
12개를 검사하니 10개가 repository 1개만 쓰고 나머지 코드는 경쟁 조건 검사·로딩 플래그라
화면 상태 관리였다. 빼면 파라미터만 넘기는 빈 껍데기가 된다.

**DTO 를 일괄 분리하지 않는 이유.** `fromJson` 호출이 repository 구현(31파일)에서만
일어나 서버 형식이 화면으로 새지 않는다. 자세한 실측과 "새 모델은 분리한다" 기준은
[Clean Architecture 전환 플레이북](/playbooks/clean-architecture-migration.md)의
"DTO/Entity 분리도 생략할 수 있다" 참고.

**글에 있고 여기 없는 것**: `features/{기능}/infrastructure/` 0개. 기능별 기술 구현이
필요한 경우가 없었다 — 플랫폼 코드는 전부 `core/` 또는 그 도메인의 기능에 있다.

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
