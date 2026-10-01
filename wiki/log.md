# Bundle Update Log

## 2026-10-01
* **쇼츠: 영상 위 세로 스와이프 먹통·전체화면에서 못 빠져나오던 버그 수정**: `youtube_player_iframe`의 `enableFullScreenOnVerticalDrag`/`autoFullScreen` 기본값(둘 다 true)이 이미 전체화면 세로 피드인 이 화면과 충돌했다 — 플레이어 위 세로 드래그를 패키지가 "전체화면 진입" 제스처로 먼저 가로채 다음 영상으로 넘기는 `PageView` 스와이프가 영상 위에서 먹지 않았고, 전체화면 진입 뒤에는 패키지 내부 `PopScope`가 시스템 뒤로가기·X 버튼의 pop을 "전체화면 탈출"로만 소비해 화면을 닫을 수 없었다. 둘 다 꺼서 해결(`shorts_embed.dart`).
* **홈 쇼츠: "응원 팀" 전환 시 안내 문구가 깜빡이던 것을 스켈레톤으로 교체**: `HomeViewModel.setShortsFilter`가 필터만 바꾸고 바로 알림을 쏴서, 응원팀 조회가 끝나기 전 중간 상태(`hasPreferredTeam=false`)가 "마이페이지에서 응원팀을 설정하면..." 안내로 그대로 그려졌다가 조회 완료 후 실제 결과로 바뀌는 깜빡임이 있었다. `shortsLoading` 플래그를 추가해 필터 전환~재조회 완료까지는 안내 대신 `_ShortsCard`와 같은 자리를 차지하는 스켈레톤 덱을 보여준다.
* **홈 순위표: "전체 경기" 링크를 월즈 전용에서 모든 리그로 되돌림**: 월즈 재비활성화(출시 보류) 작업 때 "전체 대진" 버튼을 `isWorlds` 조건부로 만들어 뒀는데, 월즈 칩이 다시 `live:false`라 이 버튼에 영원히 도달할 수 없었다. 리그와 무관하게 항상 보이는 "전체 경기" 버튼(경기 리스트로 이동)으로 되돌렸다. l10n 키를 `homeStandingsWorldsSeeAllBracket`에서 범용 `homeStandingsSeeAllMatches`로 교체.
* **홈 커뮤니티·평점 섹션 텍스트 크기 축소**: mockup.html 기준(`.post .ti` 14px, `.post .me` 11px, `.rv .c` 13.5px, `.rv .m` 11px)보다 커 보이던 글 제목·한줄평 본문(16→14)과 메타 텍스트(13→11)를 맞춰 줄였다.
* **홈 솔랭 폴링: 조회가 5초 넘게 걸리면 카드가 멈추고 요청이 쌓이던 버그 수정**: `Timer.periodic(5초)`가 이전 `_loadSolo()` 응답을 기다리지 않고 다음 틱을 쏘는 구조였다. 솔랭 API 응답이 폴링 간격(5초)보다 오래 걸리면, 다음 틱이 `_soloGen`을 먼저 올려 버려서 느리게 돌아온 응답까지 전부 "세대 불일치"로 버려지고 솔랭 카드가 갱신을 멈추는데, 동시에 5초마다 새 요청만 계속 쌓이는 문제가 있었다(CodeRabbit 리뷰 지적). `_soloPollInFlight` 플래그로 이전 조회가 끝나기 전엔 새 틱을 건너뛰도록 수정.
* **경기 리스트·필터: 데마시안컵(DEMACIA_CUP) 리그 아이콘 추가 + 알림 버튼 노출**: ASIAN_GAMES 추가 선례(2026-09-24/29)와 같은 패턴 — `assets/icons/leagues/demacia-cup.svg` 아이콘 추가, `lib/util/league_icon.dart`의 `_leagueIcons` 맵에 등록(경기 리스트 리그 헤더·필터 시트·경기 상세 Total Kills 영역이 모두 이 맵 하나를 공유해 재사용), `ApiConfig._allRealLeagueCodes`(league=ALL 펼침 목록)에도 추가해 이 리그만 있는 날 "오늘의 경기"가 조용히 비는 버그를 사전 차단. `MatchCard._isAlarmEligibleLeague` 화이트리스트(LCK·MSI·EWC·KeSPA·ASIAN_GAMES)에도 추가해 데마시안컵 경기에 알림 벨 버튼이 뜨게 함.
* **홈 순위표: 월즈(롤드컵) 카드 구현 — 스위스 전적 버킷 + 토너먼트 대진 (칩은 비활성 유지)**: 리그 테이블(`StandingsResult`)과 형식이 달라 전용 모델(`WorldsStandings`·`WorldsBracketRow`·`WorldsKnockoutRound`·`WorldsMatch`)을 새로 두고, warding-docs `features/home/mockup.html`의 `bodySwiss()`/`bodyTree()` 시안을 따라 스위스 스테이지 전적 버킷(3-0~0-3, 진출/탈락 색 구분)과 토너먼트 대진(8강→4강→결승, 라운드 간 브래킷 연결선·오늘 경기 강조·결승 그라디언트 테두리)을 카드 하단 버튼으로 전환하게 구현(`HomeViewModel.worldsView`/`toggleWorldsView`). 백엔드가 월즈를 지원하지 않고 포맷도 리그 테이블과 달라, `StandingsRepository.fetchWorldsStandings()`는 `HOME_MOCKS` 게이트 뒤의 목업만 반환한다. 코드는 완성했지만 **리그 칩은 출시 보류로 다시 `live: false`** — 사용자에게는 아직 안 보인다(LPL·LEC·LCS와 같은 비활성 점선 칩). 리그 칩 코드값은 `ApiConfig`의 리그 코드 체계와 맞춰 `'월즈'`에서 `'WORLDS'`로 변경해 뒀다(라벨은 한글 유지) — 나중에 켤 때는 `live: true`만 뒤집으면 된다.
* **홈 평점 한줄평: 독립 섹션 신설 + 백엔드 연동**: nar-back-repo#542 배포로 `GET /api/mobile/ratings/recent`가 열려 `ApiReviewSource`를 추가하고 `defaultReviewSource()` 기본값을 `EmptyReviewSource`에서 교체. 평점을 커뮤니티 섹션의 탭(최신/평점 토글)에서 떼어내 커뮤니티 섹션 바로 아래 독립 섹션(`HomeReviewSection`)으로 신설 — 커뮤니티와 같은 레이아웃(헤더 + 부제 "최신순" + `HomeListBox`, 커뮤니티 `_ListBox`를 공용화)을 쓰고 최대 5건만 보여준다(`HomeViewModel.reviews`). `HomeCommunitySort`에서 `review`를 제거하고 커뮤니티 기본 정렬은 `latest`로 바꿈. 한줄평이 없으면 `HomeReviewSection`이 섹션 전체(헤더 포함)를 그리지 않는다.

## 2026-09-30
* **쇼츠 앱 내 재생(전체화면 세로 피드)**: 카드 탭 시 유튜브 앱 대신 `ShortsFeedScreen`을 연다. `youtube_player_iframe` 추가(네이티브 → 스토어 릴리스 필요), `ShortsRepository.fetchShortsPage(page)`·`StoryVideo.channelProfileUrl` 추가, 무음·±1 WebView·오류 자동 스킵·필터(전체/내 팀). iOS 시뮬레이터 검증, Android·실기기 미확인.
* **홈 쇼츠: 내 선수 제거·응원팀 기반 내 팀·카드 10개·세로 썸네일**: `shorts-player-requirements` 결정안 3단계 반영. `HomeShortsFilter.player`·`matchedPlayer`·`_PlayerTag`·문자열 매칭을 걷어내고 "전체"는 순수 최신순, "내 팀"은 마이페이지 응원팀(`teamCode` 쿼리 + 응답 `teamCode`로 재확인)으로 바꿈. 카드는 10개, 썸네일은 `oardefault.jpg` 우선·서버 썸네일 폴백. `intent/youtube-shorts/intent.md` 갱신.

## 2026-09-29
* **홈 UI 다듬기 — 순위표·하단 네비·쇼츠·솔로 랭크 배지**: (1) 순위표 팀 로고를 키우고(28→직접 조정) 승-패·세트 득실 컬럼 사이 8px 간격 누락분 추가(mockup CSS 그리드 gap과 맞춤). (2) 하단 네비를 홈 화면에서도 다른 탭처럼 스크롤 시 축소되게 `BottomNavShrinkController` 연결, 활성 탭 칩의 `minWidth: 105` 고정폭 제거하고 패딩을 `vertical 12·horizontal 16`으로 변경. (3) 쇼츠 "전체/내 선수/내 팀" 필터 칩 간격을 8→6으로 좁힘(`NarChipMultiSelect`에 `gap` 파라미터 추가, 다른 칩 줄은 기본값 8 유지). (4) 쇼츠 영상 썸네일의 팀 코드 텍스트 배지("KT")를 팀 로고 이미지로 교체, 제목·조회수 텍스트를 조금 키우고 두껍게. (5) 솔로 랭크 카드의 "솔로 랭크"·"OO 플레이 중" 배지 점을 오늘 경기 LIVE 배지와 같은 1.2초 깜박임 애니메이션으로 통일 — `NarLiveDot`에 `color` 파라미터를 추가해 재사용(기존 정적 `_Dot` 제거).
* **홈 오늘 경기: 새 리그(ASIAN_GAMES) 낀 날 섹션 통째로 사라지던 버그 수정**: `league=ALL`을 실제 리그 코드로 펼치는 `ApiConfig._allRealLeagueCodes`가 하드코딩 목록이라 백엔드에 새로 추가된 `ASIAN_GAMES`를 못 따라가 빠져 있었다. 그 리그 경기만 있는 날(2026-09-29)은 홈 "오늘의 경기"가 항상 빈 걸로 나왔다 — 목록에 추가해 해결. 배지에 `ASIAN_GAMES...` 원본 코드가 그대로 잘려 보이는 표시 문제는 별도(미결 항목에 기록).
* **홈 솔랭: 진행 중 0명 + 끝난 경기 있음일 때 조용한 행이 사라지던 것 수정**: 스펙 변경(아래 항목)을 처음 구현할 때 조용한 행을 끝난 경기 줄로 통째로 대체했는데, "조용한 행이 없어지면 안 된다, 위에 그대로 뜨고 그 아래에 끝난 경기 줄이 이어져야 한다"는 피드백으로 두 UI를 함께 보여주도록 수정.
* **홈 끝난 경기 줄: 선수 사진·"+N명" 칩 제거**: 원형 아바타를 팀 로고(`TeamCodeBadge`)에서 선수 사진(`playerImageUrl`, `_Face` 재사용)으로 바꿈. `HomeFinishedSoloPlayer`·`ApiSoloRankSource._finished()`에 `playerImageUrl` 추가. 소식 없는 선수 수를 알려주던 "+N명" 칩(`_HiddenCountChip`)은 없앰 — 실제로 끝난 경기가 있는 선수 칩만 보여줌. `spec.md` "결정"에 반영.
* **홈 솔랭 카드 잔손질**: 큰 카드의 경과 시간을 서버 `startedAt` 기준으로 매초 기기 시계 카운트업(`HomeSoloRankSection`의 1초 타이머). 카드 테두리를 `foregroundDecoration`으로 맨 위에 그려 챔피언 스플래시·선수 사진에 가려 끊겨 보이던 문제 수정. 선수 사진을 시안(`mockup.html` `.hero .ph`, 176×214)만큼 키움.
* **홈 오늘 경기 없을 때 간격 두 배 버그 수정**: `HomeTodayMatchesSection`이 오늘 경기 0건이면 통째로 사라지는데 앞뒤 `SizedBox(28)`가 둘 다 남아 순위표 위 간격이 두 배였다. 섹션과 그 앞 간격을 묶어 같이 없앰.
* **홈 솔랭: 진행 중 0명이어도 끝난 경기가 있으면 보여줌(스펙 변경)**: 원래 진행 중 0명이면 무조건 한 줄 조용한 행이었는데, 그 안의 "마지막 경기" 텍스트가 잘리는 문제를 고치다 보니 끝난 경기 목록 자체가 아예 안 보인다는 피드백으로 이어짐. `soloState`를 "진행 중·끝난 경기 둘 다 0명일 때만 noneActive"로 바꾸고, 진행 중 0명 + 끝난 경기 있음이면 큰 카드(스와이프) 없이 끝난 경기 줄(+N명·구독 전체)부터 보여줌. 조용한 행의 "마지막 경기" 보조 텍스트는 이제 도달 불가라 제거. `spec.md` "상태" 표·"결정"에 반영.
* **홈 → 내 선수 뒤로가기 시 솔랭 새로고침**: 홈은 앱 복귀(30초 스로틀)에만 새로고침돼서, 내 선수 화면에서 선수 상태가 바뀐 걸 보고 돌아와도 홈은 그 이전 스냅샷을 유지했다. `HomeViewModel.refreshSoloOnReturn()` 추가, `_openMyPlayers`가 알림함과 같은 방식(`await push` 뒤 targeted 새로고침)으로 호출.

## 2026-09-27
* **홈 솔랭·뉴스 백엔드 연결**: `ApiSoloRankSource`(`/api/mobile/me/solo-rank`)·`ApiNewsSource`(`/api/home/news`)를 기본 소스로. `HOME_MOCKS` 기본값을 꺼짐으로 바꿈. 평점 한줄평은 백엔드 #542 배포 전이라 빈 소스 유지. 커뮤니티 인기순 칩 제거. [홈](/features/home.md) 갱신.
* **홈 오늘 경기 "일정 전체" 중복 제거**: 헤더 링크와 스트립 마지막 카드가 같은 화면에 두 번 보이던 걸 헤더 링크 하나로 정리. 경기가 없으면 섹션 전체를 숨김. `ScheduleRepository`에 `resetCacheForTesting()` 추가(테스트 간 날짜별 캐시 오염 방지).
* **홈 솔랭 조용한 행에 선수 얼굴**: 솔랭 중인 선수가 없을 때 구독 선수 사진 4명을 겹쳐 보이고(넘치면 +N), 글은 구독 수 / 마지막 경기 두 줄로 나눔(시안 `.quiet`).
* **홈 오늘 경기 카드 시안 반영**: `mockup.html`의 `.mc` 기준으로 재작성 — 로고 24(원 없는 `TeamLogo`, 로고 없으면 둥근 네모에 코드), 코드 14·점수 16, 진 팀 흐림, LIVE 배지에 깜박이는 점, 카드 높이 110.
* **홈 뉴스 썸네일**: `HomeNewsArticle.hasThumbnail`을 `thumbnailUrl`로 바꾸고 뉴스 행에 기사 썸네일 이미지를 그림(없으면 빈 자리).
* **홈 팀 배지 로고화**: `TeamCodeBadge`가 팀 코드 텍스트 대신 로고 이미지를 그림. 코드만 오는 자리는 `TeamLogoDirectory`로 조회, 실패 시 텍스트 폴백.

## 2026-09-24
* **홈 화면 완료(spec v29)**: 홈이 앱 진입 화면이 됨(스플래시·로그인·온보딩 완료 → `HomeScreen`). 솔랭·오늘 경기·순위표·커뮤니티·콘텐츠 5섹션과 내 선수 화면 추가. 솔랭·평점·뉴스는 목업(`SoloRankSource`·`ReviewSource`·`NewsSource`), 백엔드 대기.
* **Creation**: [홈](/features/home.md) 개념 문서 추가.
* **홈 최종 리뷰 수정**: 솔랭·평점·뉴스 목업을 `HOME_MOCKS` 게이트(기본값 `kDebugMode`) 뒤로 옮김 — 릴리즈 빌드는 빈 소스, 빈 뉴스·한줄평이면 해당 탭을 숨김. 순위 칩·쇼츠 sort 문구 정정.
* **홈 새로고침·탭 전환**: 앱 복귀 시 새로고침(30초 스로틀)과 섹션별 최신 응답 우선 가드 추가. "커뮤니티 전체"가 탭 루트를 쌓지 않게 `pushReplacement`로 변경.
* **솔랭 분류 공용화**: 홈 솔랭 항목을 실제 구독 선수로 거르고, 홈·내 선수 화면이 `SoloRankClassification`(`solo_rank_rules.dart`) 하나를 쓰도록 통일.
* **홈 잔손질**: 배너 닫기 경쟁 조건 수정, 쇼츠 팀 매칭을 낱말 경계로, 쇼츠는 https 주소만 연다, 오늘 경기 LIVE 판정을 `isLiveMatchStatus`로, `SoloRankSnapshot.subscribedTotal` 제거, 내 선수 줄 key 를 playerId 로.

## 2026-06-22
* **#11 완료**: 비회원 온보딩 로컬 저장 + 로그인 동기화. `OnboardingSelection` 모델·`OnboardingPreferenceRepository`·`OnboardingSyncService` 추가, `OnboardingViewModel`·`login_screen` 연동.

## 2026-06-21
* **Initialization**: warding 프로젝트 지식 번들 생성 (OKF v0.1).
* **Creation**: [개요](/overview.md), [아키텍처](/architecture/), [디자인](/design/), [기능](/features/), [플레이북](/playbooks/), [레퍼런스](/references/) 디렉토리 구성.
* **Note**: 진행 상황·TODO는 [GitHub 프로젝트 보드](/references/github-project.md)와 [CLAUDE.md](../CLAUDE.md)를 단일 출처로 한다.
* **Automation**: `gen_viz.py`(시각화), `sync_github.py`(보드→`references/github-project.md` 동기화) 추가. `.md` 편집 시 viz 자동 재생성(훅), `/sync-github`로 보드 갱신.
