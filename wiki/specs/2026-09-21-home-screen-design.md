> 2026-09-24: spec v29 기준 계획(docs/superpowers/plans/2026-09-24-home-screen-v29.md)으로 대체됨.

# 홈 화면 (Phase 1) 설계

- 날짜: 2026-09-21
- 근거: `/Users/yunhongbi/Downloads/warding-home-final.html` 목업 (5섹션: 구독 선수 솔랭 상태 · 오늘 경기 · 순위표 · 커뮤니티 · 유튜브 쇼츠)
- 관련 intent: [intent/youtube-shorts/intent.md](../../../intent/youtube-shorts/intent.md) (Phase 1 범위 절 참고)

## 배경

목업은 다섯 섹션과 여러 상태(솔랭 진행 중/끝난 직후/구독 0명 등)를 제안하지만, 조사 결과
백엔드가 아직 지원하지 않는 부분이 있다:

- 구독 선수의 **실시간 솔랭 상태를 조회하는 REST API가 없다**. FCM push(`solo_rank_notification`)로만
  들어오고, 홈 진입 시 새로 불러올 방법이 없다.
- `/api/standings`는 **정규 리그 테이블만** 지원한다(`supported=false`인 경우 `reason` 필드로
  이유를 준다). 월즈 스위스 스테이지·토너먼트 대진표 같은 비-리그-테이블 형태는 이 API로 불가능.
- `/api/mobile/community/posts`에는 **정렬(sort) 파라미터가 없다**. 최신순/인기순 탭 전환 불가,
  서버가 주는 단일 순서(사실상 최신순)만 가능.
- `/api/story/videos`(쇼츠)에는 **선수·팀 연관 필드가 없다**. "내 선수"/"내 팀" 필터는 제목
  문자열 매칭을 새로 구현해야 하는데, 이번 단계에서는 만들지 않는다.

이 설계는 사용자와 협의해 위 네 가지를 축소하고, **지금 실데이터로 채울 수 있는 것만** 1차로
구현하는 것을 목표로 한다.

## 범위

**포함 (Phase 1)**

1. 공지 배너 (`/api/notices/promoted`)
2. 오늘의 경기 가로 스트립 (`/api/schedule`)
3. 순위표 — 리그 테이블만, 리그 칩(LCK/LPL/LEC/LCS) 전환
4. 커뮤니티 — 단일 순서 리스트 (정렬 탭 없음)
5. 유튜브 쇼츠 — "전체" 필터만, 탭하면 외부 유튜브로 이동
6. 하단 탭바에 "홈" 탭 추가, 앱 진입 화면을 홈으로 변경

**제외 (다음 단계로 미룸)**

- 구독 선수 솔랭 상태 히어로 섹션 전체 (실시간 조회 API 준비되면 재논의)
- 월즈 등 스위스/토너먼트 순위 뷰
- 커뮤니티 최신순/인기순 탭
- 쇼츠 "내 선수"/"내 팀" 필터, 인앱 재생
- "구독 N명 전체" 진입점 (히어로 섹션과 함께 보류)

## 아키텍처

기존 `ScheduleViewModel`이 쓰는 패턴을 그대로 따른다: 화면 하나에 ViewModel 하나, 그 안에서
여러 repository를 병렬로 호출하되 **섹션마다 독립된 로딩/에러 상태**를 갖는다. 한 섹션이
실패해도 나머지 섹션은 정상 렌더링되고, 실패한 섹션만 인라인 재시도 UI를 보여준다.

```
HomeScreen (View)
  └─ ListenableBuilder(HomeViewModel)
       ├─ HomeNoticeBanner        (NoticeRepository.fetchPromoted)
       ├─ HomeTodayMatchesSection (ScheduleRepository.fetchMatchesByDate)
       ├─ HomeStandingsSection    (StandingsRepository.fetchStandings) [신규]
       ├─ HomeCommunitySection    (CommunityRepository.fetchPosts)
       └─ HomeShortsSection       (ShortsRepository.fetchShorts)       [신규]
```

`HomeViewModel` 생성자는 기존 관례대로 각 repository를 선택적 DI로 받고 기본값은 싱글턴
인스턴스를 쓴다. 캐시 가능한 값(공지 배너 `cachedPromoted`)은 생성자에서 동기로 먼저 채우고,
나머지는 fire-and-forget 비동기 로드로 채운다.

## 데이터 계층

### 재사용

| 대상 | 시그니처 |
|---|---|
| `ScheduleRepository.instance.fetchMatchesByDate(DateTime.now())` | `Future<List<ScheduleMatch>>` — 30초 TTL 캐시 내장 |
| `NoticeRepository.instance.fetchPromoted()` / `.cachedPromoted` | `Future<List<Notice>>` / 동기 캐시 getter |
| `NoticePreferenceRepository` | 배너 닫기 상태(dismissed id Set) |
| `CommunityRepository.instance.fetchPosts(size: ...)` | `Future<CommunityRemotePostPage>` — `sort` 파라미터 없음 |
| `isLiveMatchStatus(String)` (`lib/util/match_status.dart`) | 라이브 여부 판정 |

### 신규

**`lib/model/standing.dart`**
```dart
class StandingsResult {
  final String league;
  final bool supported;
  final String? reason;
  final String scopeLabel;
  final List<StandingGroup> groups;
}
class StandingGroup {
  final String name;
  final List<StandingRow> rows;
}
class StandingRow {
  final int rank;
  final String teamCode;
  final String teamName;
  final String? imageUrl;
  final int wins, losses, setWins, setLosses;
  final int setDiff;
}
```

**`lib/repository/standings/standings_repository.dart`**
```dart
class StandingsRepository {
  StandingsRepository._();
  static final instance = StandingsRepository._();
  Future<StandingsResult> fetchStandings(String league); // GET /api/standings?league=
}
```
기존 6개 repository와 동일 패턴(`api_client.dart` 통한 `http.get`, non-2xx → Exception,
수동 `jsonDecode` 파싱). 캐싱은 두지 않는다(칩 전환마다 새로 불러도 무리 없는 크기).

**`lib/model/story_video.dart`**
```dart
class StoryVideo {
  final String videoId, youtubeVideoId, title, videoUrl, thumbnailUrl;
  final String channelName, channelProfileUrl;
  final int viewCount, likeCount, commentCount;
  final DateTime publishedAt;
}
```

**`lib/repository/shorts/shorts_repository.dart`**
```dart
class ShortsRepository {
  ShortsRepository._();
  static final instance = ShortsRepository._();
  Future<List<StoryVideo>> fetchShorts(); // GET /api/story/videos?category=shorts&sort=latest
}
```

## 화면 구성

- `lib/screens/home/home_screen.dart` — 기존 고아 껍데기(`HomeScreen`, placeholder만 있고
  어디서도 참조 안 됨)를 실제 구현으로 교체.
- `lib/screens/home/component/` — 섹션별 위젯:
  - `home_notice_banner.dart`
  - `home_today_matches_section.dart`
  - `home_standings_section.dart` (리그 칩 + 순위 테이블 + `supported=false` 시 `reason` 인라인 안내)
  - `home_community_section.dart`
  - `home_shorts_section.dart` (탭하면 `url_launcher`로 외부 유튜브 오픈)
- `lib/viewmodel/home/home_viewmodel.dart`

순위표 칩은 LCK/LPL/LEC/LCS 네 개만 노출한다(월즈는 리그 테이블 형태가 아니므로 Phase 1에서
칩 자체를 뺀다). 칩을 탭하면 해당 리그로 다시 fetch하고, 응답이 `supported=false`면 목록 대신
`reason` 텍스트를 보여주는 빈 상태 카드를 렌더링한다.

## 탭바 변경

- `AppNavTab`에 `home`을 추가해 6탭: **홈 · 일정 · 리스트 · 커뮤니티 · 구독 · 마이**.
- `SplashScreen`, `LoginScreen`, `OnboardingScreen`의 이동 대상을 `ScheduleScreen()` →
  `HomeScreen()`으로 변경 — 홈이 로그인/온보딩 완료 후 진입 화면이 된다.
- 탭 전환은 현재 중앙 라우터 없이 5개 화면 각각에 `_onTabSelected` 분기가 중복 구현돼 있음
  (`schedule_screen.dart`, `match_list_screen.dart`, `community_screen.dart`,
  `subscription_screen.dart`, `mypage_screen.dart`). 이 다섯 곳 모두에 홈 케이스를 추가한다.
  (라우팅을 중앙화하는 리팩터는 이번 스코프 밖 — 기존 패턴을 그대로 따른다.)
- 하단 네비 바(`AppBottomNav`)는 폭이 `335*scale`(내부 패딩 제외 실사용 `311*scale`)로 고정돼
  있다. 현재 5탭은 활성 pill(minWidth 113) + 비활성 4×40=160 → 273으로 여유가 있지만, 6탭이면
  113 + 5×40=200 → 313으로 311을 넘는다. 비활성 아이템 크기(`_inactiveSize`)를 40→36 내외로
  줄여 6탭에 맞춘다.

## 에러·로딩 처리

- 섹션별 상태: `idle → loading → loaded | error`. `HomeViewModel`에 섹션당 필드
  (`List<ScheduleMatch>? todayMatches`, `String? todayMatchesError`, ...) 또는 작은
  `SectionState<T>` 헬퍼 중 구현 시점에 더 단순한 쪽으로 선택.
- 전체 화면을 막는 로딩 스피너는 없다. 첫 프레임부터 섹션별 스켈레톤/캐시된 값을 보여주고,
  개별 섹션이 채워지는 대로 갱신된다.
- 실패한 섹션은 "불러오지 못했어요 · 다시 시도" 인라인 카드를 보여주고, 나머지 섹션 렌더링에는
  영향 없음.
- Pull-to-refresh로 전체 섹션 재요청.

## 테스트 계획

- `test/viewmodel/home/home_viewmodel_test.dart`: 4개 repository를 mock으로 주입해
  - 전부 성공 시 각 필드가 채워지는지
  - 한 섹션만 실패해도 나머지가 정상인지
  - 순위표 리그 전환 시 재요청되는지
- `test/repository/standings/standings_repository_test.dart`,
  `test/repository/shorts/shorts_repository_test.dart`: 정상 응답 파싱 + non-2xx 예외.
- `test/screens/home/home_screen_test.dart` (위젯 테스트): 섹션 렌더링, 섹션 에러 상태 렌더링,
  6탭 네비 바 오버플로 없음(pump 후 overflow 에러 없는지).

## 미해결로 남기는 것 (문서화만, 이번 스코프 아님)

- 순위표 라이즈 그룹 펼치기/접기(목업엔 있으나 리그 API 응답의 `groups`가 실제로 몇 개
  오는지는 구현 중 실데이터로 확인 필요 — LCK가 레전드/라이즈 두 그룹으로 오면 그대로
  펼침 UI를 넣고, 한 그룹만 오면 뺀다).
- 섹션 순서 커스터마이즈, 구독 0명 홈 빈 상태(히어로 제외로 자연히 보류), 접근성(스와이프
  대체 수단 — Phase 1엔 스와이프 자체가 없는 섹션들이라 해당 없음).
