---
type: Feature
title: 홈
description: 앱 진입 화면. 구독 선수 솔랭·오늘 경기·순위표·커뮤니티·콘텐츠·평점 한줄평 6개 섹션과 내 선수 화면. 솔랭·뉴스·평점 모두 실제 API(HOME_MOCKS=true면 목업).
tags: [home, mvvm, mock]
timestamp: 2026-10-01T00:00:00Z
---

# 개요

홈은 앱의 진입 화면이다. 스플래시(로그인 상태)·로그인(온보딩 완료 계정)·온보딩 완료 후 모두 `HomeScreen`으로 들어오며, 하단 네비에 '홈' 탭이 있다. 상태와 로직은 `HomeViewModel`이 갖고, 화면은 섹션별 위젯으로 나눠 렌더링만 한다. 기준 spec은 v29다.

솔랭 상태·평점 한줄평·뉴스는 `lib/repository/home/home_sources.dart`의 `SoloRankSource`·`ReviewSource`·`NewsSource` 인터페이스 뒤에 있다. 기본은 셋 다 `home_api_sources.dart`의 실제 API 구현체(`ApiSoloRankSource`·`ApiReviewSource`·`ApiNewsSource`)다. 평점 한줄평은 백엔드 nar-back-repo#542(선수 이름·챔피언 한글명) 배포 후 `GET /api/mobile/ratings/recent`로 연결했다(2026-10-01). `HOME_MOCKS` 스위치로 목업을 켠다(아래 "목업 게이트").

# 화면 구성

위에서 아래 순서다.

1. **구독 선수 솔랭** - 진행 중·끝난 솔랭 카드. 구독 0명이면 점선 빈 카드를 보인다. 구독은 있는데 진행 중인 선수도 오늘 끝난 경기도 없으면 한 줄 조용한 행(구독 선수 사진 4명이 겹쳐 놓이고, 구독이 더 많으면 "+N", 글은 구독 수 한 줄)이다. **진행 중인 선수가 0명이어도 오늘 끝난 경기가 있으면, 위쪽 큰 카드(스와이프) 자리에 그 조용한 행을 그대로 보여주고 그 아래에 끝난 경기 줄("구독 N명 전체" 포함)을 잇는다**(2026-09-29 결정, spec.md 반영 — 처음엔 조용한 행을 끝난 경기 줄로 통째로 대체했다가, "조용한 행이 사라지면 안 된다"는 피드백으로 둘 다 보이게 수정). 끝난 경기 줄에는 실제로 끝난 경기가 있는 선수 칩만 보이고, 나머지(소식 없음 포함)를 위한 "+N명" 칩은 없다 — 원형 아바타는 팀 로고가 아니라 선수 사진(`_Face`, 없으면 이름 이니셜)이다. "구독 N명 전체"를 누르면 내 선수 화면을 연다. 솔랭 항목은 실제 구독 목록에 있는 선수만 보인다. 분류 규칙(이름 매칭, 진행 중 선수는 끝난 경기에서 제외, 선수당 최신 1건)은 `lib/viewmodel/home/solo_rank_rules.dart` 하나를 홈과 내 선수 화면이 함께 쓴다. 끝난 경기 최대 8명은 홈만의 상한이다. 큰 카드의 경과 시간은 서버가 준 `startedAt`을 기기 시계로 매초 다시 계산해 카운트업한다(`HomeSoloRankSection`의 1초 타이머). **이 타이머는 진행 중(`soloLive`) 카드가 있을 때만 돌고, 앱이 백그라운드로 가면 멈춘다.** 틱은 `ValueNotifier`로 경과 시간 텍스트만 갱신한다 — 예전엔 `setState(() {})`로 섹션 전체(챔피언 스플래시·선수 사진·`PageView`·끝난 경기 칩 줄)를 매초 다시 그렸고, 조건이 `soloState == active`라 끝난 경기만 있어 카운트업할 대상이 없을 때도 돌았다(실측: 10초에 섹션 빌드 10회 → 0회, 2026-10-02 수정). 카드 테두리는 챔피언 스플래시·선수 사진 위에 `foregroundDecoration`으로 맨 위에 그려, 사진이 모서리까지 닿아도 끊겨 보이지 않는다. 카드 안 "솔로 랭크"·"OO 플레이 중" 배지의 점은 오늘 경기 LIVE 배지와 같은 `NarLiveDot`(1.2초 주기 깜박임, 동작 줄이기 설정 시 고정)을 색만 `narSoloDot`으로 바꿔 재사용한다.
2. **오늘 경기** - 오늘 일정 카드(폭 172·높이 110, 팀 로고 24·코드 14·점수 16. 끝난 경기의 진 팀은 흐리게, 이긴 팀 점수는 빨강, LIVE 배지에는 깜박이는 점). 일정 탭으로 가는 길은 헤더의 "일정 전체" 링크 하나뿐이다 — 스트립 끝에 같은 링크의 카드를 또 두면 한 화면에 두 번 보여서 뺐다. 경기가 없으면 섹션 전체를 그리지 않는다. 마지막 카드에서 일정 탭으로 이동한다. 모든 리그를 보여주는 `league=ALL` 요청은 클라이언트가 실제 리그 코드로 펼쳐 보낸다(`ApiConfig.allRealLeagueCodes`). 이 목록은 **`/mobile/schedules/filters` 응답으로 갱신**되므로(`ApiConfig.updateLeagueCodes`), 백엔드에 새 리그가 추가되면 앱이 자동으로 따라간다 — `ApiConfig.fallbackLeagueCodes` 는 첫 실행·오프라인처럼 아직 목록을 못 받았을 때만 쓰는 폴백이라 여기에 리그를 더하는 것으로 대응을 끝내지 않는다. 예전엔 이 목록이 하드코딩이라 손으로 맞춰야 했고, `ASIAN_GAMES` 를 빠뜨려 그 리그만 있는 날 섹션 전체가 조용히 사라졌다(2026-09-29). 같은 목록을 쓰는 iOS 홈 위젯에는 App Group(`widget_all_league_codes`)으로 내려보낸다 — 위젯 Swift 사본이 앱보다 뒤처져 `ASIAN_GAMES`·`DEMACIA_CUP` 이 빠진 채였고, 그 리그만 있는 날 위젯이 "경기 없음" 으로 비었다(2026-10-02 수정).
3. **순위표** - 리그 칩 LCK·LPL·LEC·LCS·월즈 중 LCK만 선택 가능하고 나머지 칩은 비활성이다. 순위표 API는 LCK만 지원한다. 행의 팀 로고·순위·승-패·세트 득실 컬럼 사이 간격은 mockup CSS 그리드(`gap:8px`)와 맞춰 모든 컬럼 사이에 8px을 둔다. 헤더 우측 "전체 경기" 링크는 선택한 리그와 무관하게 항상 보이고 누르면 경기 리스트 화면을 연다(오늘 경기 섹션의 "일정 전체"와 같은 패턴). 월즈는 리그 테이블과 형식이 달라(`WorldsStandings` — 스위스 스테이지 전적 버킷 + 토너먼트 대진, warding-docs `features/home/mockup.html`의 `bodySwiss()`/`bodyTree()` 시안) 전용 카드(`_WorldsStandingsCard`)와 뷰 전환(`HomeViewModel.toggleWorldsView`)까지 구현해 뒀지만, 칩은 출시 보류로 다시 비활성(`live: false`)이다 — 백엔드가 월즈를 지원하지 않고(스위스+토너먼트 포맷이라 리그 테이블 API로도 못 받는다) 목업만 있는 채로 내보내지 않기로 했다. 코드는 그대로 남겨 뒀으니 칩의 `live` 값만 켜면 바로 다시 보인다(`HOME_MOCKS=true`에서만 데이터가 옴).
4. **커뮤니티** - 글 목록(기본 최신순). 인기순 칩은 커뮤니티가 활성화될 때까지 뺐다(백엔드 `sort=hot`은 남아 있고 `HomeCommunitySort.hot`도 남겨 뒀다). 평점 한줄평은 2026-10-01부터 이 섹션의 탭이 아니라 바로 아래 독립 섹션(5번)이다.
5. **평점 한줄평** - 커뮤니티 섹션 바로 아래 독립 섹션(`HomeReviewSection`). 커뮤니티 섹션과 같은 레이아웃(헤더 + 부제 "최신순" + 둥근 목록 상자, `HomeListBox`)을 쓰고 최대 5건만 보여준다(`HomeViewModel.reviews`). 탭 전환은 없고(부제는 고정 텍스트) 한줄평이 없으면 섹션 전체(헤더 포함)를 그리지 않는다.
6. **콘텐츠** - 뉴스·쇼츠 탭. 기본은 뉴스이고, 뉴스가 없으면 뉴스 탭을 숨겨 쇼츠만 보인다. 쇼츠는 10개 팀 공식 채널 + LCK 공식 채널만, 순수 최신순으로 카드 10개를 보이고 "전체/내 팀" 하위 필터 칩을 둔다. "내 팀"은 마이페이지 응원팀(없으면 로컬 캐시)이고 LCK 영상은 "전체"에만 나온다. 필터를 바꾼 직후 응원팀·영상을 다시 받는 동안은(`HomeViewModel.shortsLoading`) 안내 문구 대신 카드 자리를 그대로 차지하는 스켈레톤 덱을 보여준다 — 응원팀 조회가 끝나기 전의 중간 상태가 "응원팀 미설정" 안내로 잘못 보였다가 실제 결과로 바뀌는 깜빡임을 막기 위해서다(2026-10-01). 응원팀이 정말 없으면 설정 안내, 0건이면 "전체 보기" 버튼을 보인다. 필터 칩은 다른 칩 줄(간격 8)보다 좁은 간격(6, `NarChipMultiSelect.gap`)을 쓴다. 썸네일은 9:16 세로 `oardefault.jpg`를 먼저 시도하고 없으면(약 25%) 서버 썸네일로 폴백한다. 좌상단 배지는 채널 팀 로고 이미지(`TeamLogo`)다. 카드를 탭하면 전체화면 세로 피드(`ShortsFeedScreen`)가 열린다 — `youtube_player_iframe`의 `enableFullScreenOnVerticalDrag`/`autoFullScreen`을 꺼서 패키지 자체 전체화면 기능과 피드의 세로 스와이프·닫기가 충돌하지 않게 했다(2026-10-01).

공지 배너와 알림 미읽음 배지도 홈 상단에 있다.

**알림 배지 범위는 벨 목적지와 같아야 한다.** 배지는 `HomeViewModel.refreshUnreadNotifications`가 알림 API의 `unreadCount`로 세는데, 이 범위가 벨이 여는 화면의 읽음 처리 범위와 어긋나면 사용자가 배지를 지울 방법이 없어진다. 2026-09-29에 벨 목적지를 알림함에서 마이구독 탭으로 바꿨는데 배지는 `group=COMMUNITY`로 남아 있어, 마이구독에서 알림을 다 읽어도 배지가 그대로 남는 버그가 있었다(2026-10-01 수정). 마이구독 피드(`SubscriptionFeedViewModel`)는 `group` 없이 전체를 읽으므로 배지도 전체로 센다. 벨 목적지를 또 바꾸면 이 범위도 함께 맞춘다.

앱이 포그라운드로 돌아오면 마지막 새로고침에서 30초 넘게 지났을 때만 전 섹션을 다시 불러온다(`HomeViewModel.refreshOnResume`). 섹션 로더마다 세대 번호가 있어 겹친 요청 중 늦게 도착한 옛 응답은 버린다. "커뮤니티 전체"는 다른 탭 전환처럼 `pushReplacement`로 커뮤니티 탭을 연다.

하단 네비는 홈을 포함한 모든 탭 화면에서 스크롤하면 `BottomNavShrinkController`로 축소된다(다른 탭과 동일한 동작으로 홈에도 연결). 활성 탭 칩은 최소 폭 없이 아이콘·라벨·패딩(수직 12·수평 16)만큼만 차지한다.

**내 선수** 화면(`screens/my_players/`)은 구독 전체를 보여주는 조회 전용 화면이다. 홈의 "구독 N명 전체"에서 push하며, 뒤로 가면 홈으로 돌아온다.

# 데이터 출처

| 영역 | 출처 | 상태 |
|------|------|------|
| 오늘 경기 | 일정 API | 실데이터 |
| 순위표(LCK) | `/api/standings` | 실데이터 |
| 순위표(월즈) | 백엔드 미지원 — `worldsStandingsMock` 코드는 있으나 칩 비활성(출시 보류) | 미노출 |
| 커뮤니티 글 | 커뮤니티 글 목록 (홈은 `sort=latest`) | 실데이터 |
| 공지 배너 | 공지 API | 실데이터 |
| 쇼츠 | `/api/story/videos` (홈은 `sort=latest&size=10`, 내 팀은 `teamCode`·`size=30`, 리포지토리는 `latest\|views\|likes` 지원) | 실데이터 |
| 구독 선수 목록·수 | 구독 API | 실데이터 |
| 알림 미읽음 배지 | 알림 API (전체 — 벨 목적지와 같은 범위) | 실데이터 |
| 솔랭 상태 | `GET /api/mobile/me/solo-rank` (`ApiSoloRankSource`, 로그인 필수) | 실데이터 |
| 평점 한줄평 | `GET /api/mobile/ratings/recent` (`ApiReviewSource`, 인증 불필요) | 실데이터 |
| 뉴스 | `GET /api/home/news` (`ApiNewsSource`, 최신 TOP 5, 썸네일 이미지 표시) | 실데이터 |

**목업 게이트:** `kHomeMocks = bool.fromEnvironment('HOME_MOCKS')`(기본 꺼짐)가 켜져 있으면 `defaultSoloRankSource()`·`defaultReviewSource()`·`defaultNewsSource()`가 목업을 준다. 꺼져 있으면 셋 다 API 소스다. `HomeViewModel`·`MyPlayersViewModel`의 기본값이 이 함수들이다. 목업 화면은 `--dart-define=HOME_MOCKS=true`로만 본다. 월즈 순위표(`StandingsRepository.fetchWorldsStandings`)도 같은 `kHomeMocks`를 보고 목업을 반환하도록 구현돼 있지만, 리그 칩 자체가 `live: false`라 지금은 사용자가 이 경로에 도달할 수 없다 — 출시 보류 결정.

솔랭 API 매핑 규칙:

- 로그인하지 않았으면(토큰 없음) 요청하지 않고 빈 결과를 준다. 서버는 토큰이 없으면 401이다.
- `live.elapsedSeconds`는 `now − startedAt`, `finished.minutesAgo`는 `now − endedAt`, `durationMinutes`는 `durationSeconds / 60`이다.
- `win`이 null인 판(결과를 못 받음)은 승/패를 그릴 수 없어 끝난 경기에서 뺀다.
- 오프셋 없는 시각(뉴스 `createdAt`)은 KST로 해석한다(`parseServerTime`).
- 큰 카드 배경 챔피언 이미지는 응답의 `championImageUrl`을 먼저 쓰고, 없을 때만 `championName`으로 Data Dragon 스플래시 URL을 만든다(`championSplashUrl`). 이름으로 URL을 만들 때는 표시명이 아니라 Data Dragon **키**를 넣어야 한다 — `champion_image.dart`의 `ChampionImage.ddragonKeyOf`가 그 변환(공백·아포스트로피·`.`·`&` 제거 + `오공`→`MonkeyKing` 같은 예외표)을 한 곳에서 담당하고, 아이콘·스플래시가 같은 키를 공유한다.

**팀 배지:** 팀 표시 원형(`TeamCodeBadge`)은 로고 이미지를 그린다. 순위표(`imageUrl`)·오늘 경기(`teamImageUrl`)는 응답의 로고를 쓰고, 팀 코드만 오는 솔랭·한줄평·내 선수·커뮤니티는 `TeamLogoDirectory`(온보딩 팀 목록 캐시 기반 코드→로고 사전)에서 찾는다. 로고를 못 구했거나 불러오는 중이면 팀 코드 텍스트로 대신한다.

비회원(JWT 없음)은 어느 쪽이든 구독 0명으로 취급해 점선 빈 카드를 보인다.

쇼츠 참고:

- spec은 `/api/videos`, `popular`로 적었지만 백엔드 코드 기준은 `/api/story/videos`, `views`다.
- "내 선수" 필터와 제목·채널명 문자열 매칭은 제거했다(2026-09-30). 팀은 응답의 `teamCode`로 거르고 서버 `teamCode` 쿼리(nar-back-repo#545, 머지 대기)가 머지되기 전에는 클라이언트가 30건을 받아 응답 `teamCode`로 거른다.
- 카드를 누르면 앱 안 전체화면 세로 피드(`screens/shorts/shorts_feed_screen.dart`, `ShortsFeedViewModel`)가 열린다. 유튜브 공식 IFrame 임베드(`youtube_player_iframe`, 네이티브 WebView라 **스토어 릴리스 필요**)로 항상 무음 재생한다. 탭한 영상부터 시작하고 끝 3개 안쪽에서 다음 페이지(`page` 파라미터)를 이어 받는다. WebView는 현재 ±1 페이지만(최대 3개). 임베드 오류면 자동 스킵, 연속 3건이면 "재생할 수 없어요"+유튜브에서 열기. 정보(채널·제목·조회수·"유튜브에서 보기")는 플레이어 바깥 하단에 둔다. iOS 시뮬레이터에서 재생·자동 다음·오류 153 없음을 확인했고 Android·실기기(프레임 드롭·메모리)는 미확인. 활성화 시 `playVideo`만으론 미리 로드된 플레이어가 시작하지 않아 `loadVideoById`로 다시 로드한다.

# 진입·내비게이션

- 스플래시: JWT가 있으면 `HomeScreen`, 없으면 로그인.
- 로그인: 온보딩을 마친 계정은 `HomeScreen`, 아니면 온보딩.
- 온보딩 완료: `HomeScreen`.
- 다른 탭(경기·일정·구독·커뮤니티·마이페이지)의 '홈' 탭은 `pushReplacement`로 `HomeScreen`을 연다. 홈에서는 '홈'을 뺀 탭을 누르면 해당 화면으로 전환한다.

# 미결·후속

- 끝난 솔랭 카드의 KDA와 "경기 결과" 진입점은 미구현이다. 솔랭 DTO(직전 결과·`gameStartTime`)가 백엔드에 필요하다.
- 진행 중 솔랭 카드의 경과 시간 카운트업도 `gameStartTime`을 기다린다.
- 핀 고정 최대 인원이 정해지지 않아 인원 제한 없이 로컬 상태로만 둔다.
- 첫 응답이 오기 전에는 섹션마다 스켈레톤을 그린다(2026-10-02): 솔랭 큰 카드+끝난 경기 칩 줄·오늘 경기·순위표·커뮤니티·평점 한줄평·뉴스(쇼츠 덱은 기존). `HomeViewModel`의 `*Loading` 플래그(첫 응답이 성공이든 실패든 해제)로 판단하고, 이후 새로고침(5초 폴링 포함)은 마지막 값을 유지하며 스켈레톤을 다시 띄우지 않는다. 오늘 경기·평점은 첫 로드 뒤 비어 있으면 섹션이 통째로 사라지고, 뉴스는 비어 있으면 쇼츠만 남는다(뉴스 대기 중엔 뉴스 탭을 둔다). 공통 펄스는 `NarSkeleton`/`NarSkeletonBox`(`lib/components/nar_skeleton.dart`), 섹션 모양은 `home_skeletons.dart`.
- 새 `narSolo*` 핑크 색 토큰은 디자인 확인이 필요하다.
- 시뮬레이터 스크린샷 수동 확인이 남았다.
- 오늘 경기 카드의 리그 배지는 백엔드 `leagueInfo`/`leagueName` 문자열을 그대로 보여준다. LCK 등은 짧은 표시 이름이 오지만 `ASIAN_GAMES`처럼 새 리그는 원본 코드가 그대로 와서 배지에서 "ASIAN_GAMES..."로 잘린다(2026-09-29 확인) — 백엔드가 표시용 이름을 내려주거나 클라이언트에 리그 코드→표시 이름 매핑이 필요하다.
- spec의 API 표에서 "새로"로 표시된 항목 중 평점 최근순(`/api/mobile/ratings/recent`)은 연결했다(2026-10-01). 솔랭 DTO·`/api/mobile/home`·한글 활동명은 이번 범위 밖이다.

# 관련

- 기준 spec: `warding-docs/features/home/spec.md` (별도 레포)
- 계획: `docs/superpowers/plans/2026-09-24-home-screen-v29.md`
- 코드: `lib/screens/home/`, `lib/screens/my_players/`, `lib/viewmodel/home/home_viewmodel.dart`, `lib/viewmodel/my_players/`, `lib/repository/home/home_sources.dart`, `lib/repository/standings/`, `lib/repository/shorts/`
- 일정은 [경기](/features/matches.md), 솔랭 알림은 [솔랭 알림](/features/solo-rank-alarm.md).

# Citations

[1] [CLAUDE.md](../../CLAUDE.md)
