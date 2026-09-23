---
type: Feature
title: 홈
description: 앱 진입 화면. 구독 선수 솔랭·오늘 경기·순위표·커뮤니티·콘텐츠 5개 섹션과 내 선수 화면. 솔랭·평점·뉴스는 목업.
tags: [home, mvvm, mock]
timestamp: 2026-09-24T00:00:00Z
---

# 개요

홈은 앱의 진입 화면이다. 스플래시(로그인 상태)·로그인(온보딩 완료 계정)·온보딩 완료 후 모두 `HomeScreen`으로 들어오며, 하단 네비에 '홈' 탭이 있다. 상태와 로직은 `HomeViewModel`이 갖고, 화면은 섹션별 위젯으로 나눠 렌더링만 한다. 기준 spec은 v29다.

솔랭 상태·평점 한줄평·뉴스는 백엔드가 준비되지 않아 목업이다. 이 셋은 `lib/repository/home/home_sources.dart`의 `SoloRankSource`·`ReviewSource`·`NewsSource` 인터페이스 뒤에 있어, 백엔드가 생기면 구현체만 교체한다.

# 화면 구성

위에서 아래 순서다.

1. **구독 선수 솔랭** - 진행 중·끝난 솔랭 카드. 구독 0명이면 점선 빈 카드를 보인다. "구독 N명 전체"를 누르면 내 선수 화면을 연다.
2. **오늘 경기** - 오늘 일정 카드. 마지막 카드에서 일정 탭으로 이동한다.
3. **순위표** - 리그 칩으로 리그를 고른다. 순위표 API는 LCK만 지원한다.
4. **커뮤니티** - 최신·인기·평점 탭. 최신·인기는 커뮤니티 글, 평점은 한줄평이다.
5. **콘텐츠** - 뉴스·쇼츠 탭.

공지 배너와 알림 미읽음 배지도 홈 상단에 있다.

**내 선수** 화면(`screens/my_players/`)은 구독 전체를 보여주는 조회 전용 화면이다. 홈의 "구독 N명 전체"에서 push하며, 뒤로 가면 홈으로 돌아온다.

# 데이터 출처

| 영역 | 출처 | 상태 |
|------|------|------|
| 오늘 경기 | 일정 API | 실데이터 |
| 순위표 | `/api/standings` (LCK만) | 실데이터 |
| 커뮤니티 글 | 커뮤니티 글 목록 (`sort=hot\|latest`) | 실데이터 |
| 공지 배너 | 공지 API | 실데이터 |
| 쇼츠 | `/api/story/videos` (`sort=latest\|views\|likes`) | 실데이터 |
| 구독 선수 목록·수 | 구독 API | 실데이터 |
| 알림 미읽음 배지 | 알림 API (COMMUNITY 그룹) | 실데이터 |
| 솔랭 상태 | `SoloRankSource` (`MockSoloRankSource`) | 목업 |
| 평점 한줄평 | `ReviewSource` (`MockReviewSource`) | 목업 |
| 뉴스 | `NewsSource` (`MockNewsSource`) | 목업 |

**릴리즈 위험:** 로그인 사용자에게는 목업 솔랭 카드가 실제 구독 수와 나란히 보인다. 솔랭 백엔드가 준비되기 전에 릴리즈하면 가짜 솔랭 상태가 노출되므로, 그 전에 구현체를 교체하거나 빈 소스로 바꿔야 한다. 비회원(JWT 없음)은 구독 0명으로 취급해 점선 빈 카드를 보이고 목업 솔랭 카드는 보이지 않는다.

쇼츠 참고:

- spec은 `/api/videos`, `popular`로 적었지만 백엔드 코드 기준은 `/api/story/videos`, `views`다.
- 응답에 팀·선수 필드가 없어 내 선수·내 팀 쇼츠 매칭은 제목·채널명 문자열 매칭이다. 한글 활동명이 생기기 전까지는 영문 이름만 잡힌다.

# 진입·내비게이션

- 스플래시: JWT가 있으면 `HomeScreen`, 없으면 로그인.
- 로그인: 온보딩을 마친 계정은 `HomeScreen`, 아니면 온보딩.
- 온보딩 완료: `HomeScreen`.
- 다른 탭(경기·일정·구독·커뮤니티·마이페이지)의 '홈' 탭은 `pushReplacement`로 `HomeScreen`을 연다. 홈에서는 '홈'을 뺀 탭을 누르면 해당 화면으로 전환한다.

# 미결·후속

- 끝난 솔랭 카드의 KDA와 "경기 결과" 진입점은 미구현이다. 솔랭 DTO(직전 결과·`gameStartTime`)가 백엔드에 필요하다.
- 진행 중 솔랭 카드의 경과 시간 카운트업도 `gameStartTime`을 기다린다.
- 핀 고정 최대 인원이 정해지지 않아 인원 제한 없이 로컬 상태로만 둔다.
- 로딩·에러 상태는 그리지 않고 마지막 값을 유지한다(spec 미결).
- 새 `narSolo*` 핑크 색 토큰은 디자인 확인이 필요하다.
- 시뮬레이터 스크린샷 수동 확인이 남았다.
- spec의 API 표에서 "새로"로 표시된 항목(솔랭 DTO·평점 최근순·`/api/mobile/home`·한글 활동명)은 이번 범위 밖이다.

# 관련

- 기준 spec: `warding-docs/features/home/spec.md` (별도 레포)
- 계획: `docs/superpowers/plans/2026-09-24-home-screen-v29.md`
- 코드: `lib/screens/home/`, `lib/screens/my_players/`, `lib/viewmodel/home/home_viewmodel.dart`, `lib/viewmodel/my_players/`, `lib/repository/home/home_sources.dart`, `lib/repository/standings/`, `lib/repository/shorts/`
- 일정은 [경기](/features/matches.md), 솔랭 알림은 [솔랭 알림](/features/solo-rank-alarm.md).

# Citations

[1] [CLAUDE.md](../../CLAUDE.md)
