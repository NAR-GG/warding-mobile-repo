---
type: Feature
title: 선수 페이지
description: 선수 한 명의 솔랭 상태·다음 경기·월즈 성적·솔랭 기록. 홈 솔랭 카드·끝난 경기 칩·월즈 솔랭 타일에서 진입.
tags: [player, solo-rank, worlds, cheer]
timestamp: 2026-10-25T00:00:00Z
---

# 상태

🚧 PR #409. API 3개는 prod 배포됨(nar-back-repo #587). `metPlayers` 는 nar-back-repo #588 배포 대기 — 그전엔 섹션이 숨겨지고, `HOME_MOCKS=true` 로 목업을 본다.

# 구현됨 / 관련 코드

- API 3개(비로그인 가능, 로그인 시 개인화 필드): `GET /api/mobile/players/{id}`, `/worlds`, `/solo-rank`.
- `model/player_detail.dart`, `repository/player/player_repository.dart`(+ `player_mock_source.dart`),
  `viewmodel/player/player_viewmodel.dart`, `screens/player/`.
- 솔랭 중이면 홈 큰 카드(`HomeSoloHeroCard`)+`SoloCheerCard` 를 그대로 쓴다. 홈에서 들어오면
  **홈의 `SoloCheerController` 를 넘겨** 응원 수가 함께 움직인다(키는 선수 이름). 월즈 솔랭에서
  들어오면 자기 컨트롤러를 만든다.
- 쉬는 중이면 프로필 줄 + 마지막 솔랭 한 판.
- 경기 알림은 경기 카드와 같은 `runMatchAlarmFlow`: 미구독이면 시트 → 확인으로 구독, 구독 중이면
  현재 설정으로 시트를 열어 변경하거나 "알림 끄기"로 해제(바로 끄지 않는다).
- 상단 벨은 월즈 솔랭 벨과 같은 선수 구독 시트(`showWorldsPlayerSheet`)를 연다 — 두 VM 이
  `PlayerSheetSource` 를 구현한다. 바로 토글하지 않는다.
- 팬 평점: 한줄평을 누르면 그 판 평점 상세(`PlayerRatingScreen`, highlightRatingId)로.
  목록은 `/worlds/reviews?page=` 로 20개씩, 바닥에 닿으면 버튼 없이 이어 붙인다.
- 진입: 홈 큰 카드·끝난 경기 칩(`finished[].playerId`)·월즈 큰 카드, 월즈 솔랭 **타일**(벨은 기존 알림 시트).
- 라우트 이름 `player_detail`.
- UI 는 [공용 컴포넌트](/design/shared-components.md)로 짠다 — 카드는 `NarCard`,
  "더 보기"는 `NarMoreButton`, 챔피언 정렬 칩은 `NarChipMultiSelect.single`, 섹션 제목은
  `PlayerSectionTitle`(= `NarSectionTitle` + 선수 페이지 간격), 상단 바는 `NarDetailHeader`,
  월즈/솔랭 탭은 `NarTabBar`, 팬 평점은 선수 평점 상세의 `RatingDistributionSection`.
  `player_parts.dart` 에는 이 페이지에서만 쓰는 조각
  (`playerText`·`ChampionIcon`·`PlayerResultRow`·`kdaSpan`)만 남는다.
- 목록 방식은 데이터 출처를 따른다. **한줄평만 무한 스크롤**(서버가 20개씩 주는 페이징 —
  처음 6개, 바닥 300 안쪽에서 이어 받는다). **최근 솔랭·챔피언 표·경기별 기록은
  "더 보기" 버튼** — 이미 전부 받아 둔 목록이라 한 번에 펼치는 게 편하다.
  첫 로딩은 `PlayerSkeleton`. 콘텐츠가 화면보다 짧으면 스크롤이 없어 리스너가 안 불리므로,
  매 프레임 뒤에 재서 스크롤 여지가 없으면 바로 다음 장을 당긴다.

# 빈 상태·결정

- 월즈 `games` 가 비면 "경기 기록 집계 중"(상류 CSV 지연). 지표 그리드는 시안대로 3열.
- 해외 팀은 상대 코드·로고가 null 일 수 있어 `opponentTeamName` 으로 대체. stage 는 블록명 그대로.
- `bestOf == 1` 이면 "단판".
- 솔랭 계정 티어가 null 이면 생략. 티어 엠블럼은 앱 에셋(`assets/images/tiers/*.webp`,
  `rankedCrestAsset`)이라 네트워크를 안 탄다 — 모르는 티어는 `unranked` 로 폴백한다.
- "솔랭에서 만난 선수"(`/solo-rank` 의 `metPlayers`, 최근 7일 최대 10명): 빈 배열이면 섹션을 숨긴다.
  `nextMatch.opponent.teamCode` 와 팀이 같으면 "다음 상대" 태그를 붙인다. 승패는 이 페이지 선수 기준이고, 시안대로 0패는 생략한다.
  카드를 누르면 그 선수의 페이지로 간다(응원 컨트롤러는 그대로 넘긴다).
- 라이브 응원 수 폴링은 없다(당겨서 새로고침).

# 관련

- [홈](/features/home.md), [솔랭 알림](/features/solo-rank-alarm.md), [선수 평점](/features/player-ratings.md)
