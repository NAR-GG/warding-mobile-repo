---
type: Feature
title: 선수 페이지
description: 선수 한 명의 솔랭 상태·다음 경기·월즈 성적·솔랭 기록. 홈 솔랭 카드·끝난 경기 칩·월즈 솔랭 타일에서 진입.
tags: [player, solo-rank, worlds, cheer]
timestamp: 2026-10-25T00:00:00Z
---

# 상태

🚧 화면 완성, 백엔드(nar-back-repo) 배포 대기. 배포 전엔 `--dart-define=HOME_MOCKS=true` 로 목업을 본다.

# 구현됨 / 관련 코드

- API 3개(비로그인 가능, 로그인 시 개인화 필드): `GET /api/mobile/players/{id}`, `/worlds`, `/solo-rank`.
- `model/player_detail.dart`, `repository/player/player_repository.dart`(+ `player_mock_source.dart`),
  `viewmodel/player/player_viewmodel.dart`, `screens/player/`.
- 솔랭 중이면 홈 큰 카드(`HomeSoloHeroCard`)+`SoloCheerCard` 를 그대로 쓴다. 홈에서 들어오면
  **홈의 `SoloCheerController` 를 넘겨** 응원 수가 함께 움직인다(키는 선수 이름). 월즈 솔랭에서
  들어오면 자기 컨트롤러를 만든다.
- 쉬는 중이면 프로필 줄 + 마지막 솔랭 한 판.
- 경기 알림 벨은 경기 카드와 같은 흐름(`showMatchAlarmSheet` + `MatchSubscriptionRepository`),
  상단 벨은 선수 구독(`SubscriptionRepository`). 비회원은 로그인으로.
- 진입: 홈 큰 카드·끝난 경기 칩(`finished[].playerId`)·월즈 큰 카드, 월즈 솔랭 **타일**(벨은 기존 알림 시트).
- 라우트 이름 `player_detail`.

# 빈 상태·결정

- 월즈 `games` 가 비면 "경기 기록 집계 중"(상류 CSV 지연). 지표 그리드는 시안대로 3열.
- 해외 팀은 상대 코드·로고가 null 일 수 있어 `opponentTeamName` 으로 대체. stage 는 블록명 그대로.
- `bestOf == 1` 이면 "단판".
- 솔랭 계정 티어가 null 이면 생략. "솔랭에서 만난 선수"·"한줄평 전체 보기" 는 2차.
- 라이브 응원 수 폴링은 없다(당겨서 새로고침).

# 관련

- [홈](/features/home.md), [솔랭 알림](/features/solo-rank-alarm.md), [선수 평점](/features/player-ratings.md)
