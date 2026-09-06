# NAR API 레퍼런스

백엔드(`https://api.nar.kr`)의 Swagger(OpenAPI 3.0.1) 스펙을 태그별로 정리한 목록이다.
요청/응답 스키마 등 전체 상세는 원본 스펙 `docs/openapi_spec.json`을 참고한다 (이 문서는 요약).

- 스펙 버전: `v3.0.0`
- 총 142개 경로, 166개 엔드포인트
- 갱신 방법: 리포지토리 루트 README의 "API 스펙 갱신" 참고

## Mobile. 마이구독 알림
마이구독 알림 리스트 전체 페이지 API

- **GET** `/api/mobile/me/notifications` — 알림 리스트 조회
- **DELETE** `/api/mobile/me/notifications` — 알림 전체 삭제
- **POST** `/api/mobile/me/notifications/read` — 알림 전체 읽음 처리
- **DELETE** `/api/mobile/me/notifications/{notificationId}` — 알림 단건 삭제
- **POST** `/api/mobile/me/notifications/{notificationId}/read` — 알림 단건 읽음 처리

## 1. 챔피언 조합 분석
챔피언 조합 승률, 1vs1 매치업 분석 데이터를 제공합니다.

- **GET** `/api/combinations/` — 챔피언 조합 조회
- **GET** `/api/combinations/matchups/1v1` — 1vs1 라인전 매치업 조회
- **GET** `/api/combinations/stat` — 데이터 업데이트 현황
- **GET** `/api/combinations/{combinationId}/detail` — 조합 상세 분석

## Mobile. 경기 리스트
모바일 경기 리스트 무한 스크롤 및 세트(게임) 조회 전용 API

- **GET** `/api/mobile/matches` — 모바일 경기 리스트 커서 페이지 조회
- **GET** `/api/mobile/matches/{matchId}` — 매치 단건 조회
- **GET** `/api/mobile/matches/{matchId}/games` — 매치 세트(게임) 목록 조회

## 2. 경기 일정
날짜별 경기 일정 및 매치 상세 정보를 조회합니다.

- **GET** `/api/schedule` — 일별 경기 일정 조회
- **GET** `/api/schedule/calendar` — 월별 경기 존재 날짜 조회
- **GET** `/api/schedule/matches/{matchId}/detail` — 매치 상세 정보 조회
- **POST** `/api/schedule/sync/history` — 과거 경기 이력 수동 동기화

## 1.2 챔피언 관리
챔피언 목록 조회 기능을 제공합니다.

- **GET** `/api/champions` — 전체 챔피언 목록 조회
- **POST** `/api/champions/sync` — 챔피언 데이터 동기화 (관리자용)
- **POST** `/api/champions/{championId}/loading-image` — 챔피언 로딩 이미지 URL 수동 업데이트

## 3. 게임 목록 조회
전체 게임 일정 및 결과 목록을 필터링하여 조회합니다.

- **GET** `/api/games` — 최근 게임 목록 검색

## Mobile. 경기 일정
모바일 앱 경기일정/경기리스트 전용 API

- **GET** `/api/mobile/schedules` — 모바일 일별 경기 리스트 조회
- **GET** `/api/mobile/schedules/calendar` — 모바일 월별 캘린더 조회
- **GET** `/api/mobile/schedules/filters` — 모바일 일정 필터 조회

## 팀 분석
팀별 상세 통계 및 레이더 차트 API

- **GET** `/api/teams/detail-stats` — 팀 경기 데이터 상세
- **GET** `/api/teams/scatter` — 팀 지표 스캐터 차트
- **GET** `/api/teams/{teamId}/dashboard` — 팀 페이지 대시보드
- **GET** `/api/teams/{teamId}/profile-header` — 팀 프로필 헤더
- **GET** `/api/teams/{teamId}/radar` — 팀 레이더 차트 통계

## Mobile. 기기 알림
Flutter FCM 기기 토큰 관리 API

- **POST** `/api/mobile/me/devices` — FCM 기기 토큰 등록 또는 갱신
- **DELETE** `/api/mobile/me/devices/{deviceId}` — 현재 기기 알림 등록 해제

## 8. 인증 / 로그인
소셜 로그인과 JWT 기반 사용자 인증 API

- **POST** `/api/auth/logout` — 로그아웃
- **GET** `/api/auth/me` — 내 정보 조회
- **PUT** `/api/auth/me` — 프로필 수정
- **DELETE** `/api/auth/me` — 회원 탈퇴
- **POST** `/api/auth/me/community-image/signature` — 커뮤니티 첨부 사진 업로드 서명 발급
- **POST** `/api/auth/me/profile-image/signature` — 프로필 이미지 업로드 서명 발급
- **POST** `/api/auth/mobile/apple` — 모바일 Apple 로그인
- **POST** `/api/auth/mobile/google` — 모바일 Google 로그인
- **POST** `/api/auth/mobile/kakao` — 모바일 카카오 로그인
- **POST** `/api/auth/mobile/naver` — 모바일 Naver 로그인
- **POST** `/api/auth/onboarding` — 온보딩 완료
- **GET** `/api/auth/onboarding/leagues` — 온보딩용 리그 목록 조회
- **GET** `/api/auth/onboarding/players` — 온보딩용 선수 목록 조회
- **GET** `/api/auth/onboarding/teams` — 온보딩용 팀 목록 조회
- **POST** `/api/auth/refresh` — 토큰 재발급
- **GET** `/login/oauth2/code/{registrationId}` — 소셜 로그인 콜백
- **GET** `/oauth2/authorization/{registrationId}` — 소셜 로그인 시작

## 5. 팀 랭킹
팀 랭킹 및 모스트 픽 데이터를 제공합니다.

- **GET** `/api/teams/rankings` — 팀 랭킹 조회

## 1.1 카테고리 정보
리그, 스플릿, 팀 정보를 트리 형식으로 조회합니다.

- **GET** `/api/categories/tree` — 카테고리 계층 구조 조회

## Mobile. 내 평가
모바일 마이페이지 내 선수 평가 모아보기 API

- **GET** `/api/mobile/me/ratings` — 내 선수 평가 전체 목록 조회

## Mobile. 알림 잠자기
정한 시간대에 푸시를 소리 없이 받는 설정

- **GET** `/api/mobile/me/quiet-hours` — 내 알림 잠자기 설정 조회
- **PUT** `/api/mobile/me/quiet-hours` — 내 알림 잠자기 설정 변경

## Mobile. 공지사항
앱 공지 목록·캘린더 띠배너 공지 조회 (인증 불필요)

- **GET** `/api/notices` — 공지 목록
- **GET** `/api/notices/promoted` — 띠배너 공지 목록
- **POST** `/api/notices/{id}/view` — 공지 조회수 증가

## 7. 검색
경기 및 팀 검색 자동완성 API

- **GET** `/api/v1/search/autocomplete` — 경기 자동완성 검색

## 5. 유튜브 스토리 서비스
프로팀 및 쇼츠 채널의 최신 영상 데이터를 제공합니다.

- **GET** `/api/story/videos` — 최신 영상 목록 조회
- **GET** `/api/story/videos/{videoId}/comments` — 영상 댓글 조회

## Mobile. 경기 예약 알림
특정 경기 예약 알림 구독 API. 팀 구독과 별개로 경기 단위로 세트 시작/종료/라이브 이벤트를 받는다.

- **GET** `/api/mobile/me/match-subscriptions` — 내 경기 예약 구독 목록 조회
- **POST** `/api/mobile/me/match-subscriptions` — 경기 예약 구독 추가
- **GET** `/api/mobile/me/match-subscriptions/{matchId}` — 경기 예약 구독 알림 상태 조회
- **PUT** `/api/mobile/me/match-subscriptions/{matchId}` — 경기 예약 구독 알림 토글 변경
- **DELETE** `/api/mobile/me/match-subscriptions/{matchId}` — 경기 예약 구독 해제

## Mobile. Live Activity
iOS 잠금화면 실시간 경기 카드의 ActivityKit 푸시 토큰 관리 API

- **POST** `/api/mobile/me/live-activities` — Live Activity 푸시 토큰 등록/갱신
- **DELETE** `/api/mobile/me/live-activities` — Live Activity 푸시 토큰 해제
- **POST** `/api/mobile/me/live-activities/start-token` — push-to-start 토큰 등록/갱신
- **DELETE** `/api/mobile/me/live-activities/start-token` — push-to-start 토큰 해제

## 7. Live API
라이브 경기 상태 조회 API

- **GET** `/api/live/games` — 현재 라이브 게임 목록 조회
- **GET** `/api/live/games/{gameId}` — 라이브 게임 최신 상태 조회
- **POST** `/api/live/games/{gameId}/backfill` — 라이브 게임 백필 실행
- **GET** `/api/live/games/{gameId}/minutes` — 분 단위 라이브 스냅샷 조회
- **POST** `/api/live/games/{gameId}/simulate` — 과거 live feed 시뮬레이션
- **GET** `/api/live/queue` — 라이브 저장 큐 상태 조회

## Mobile. 라이브 경기 상세
모바일 경기 상세 화면용 라이브 챔피언 픽/밴 및 이벤트 타임라인 API

- **GET** `/api/mobile/live/games/{gameId}/champions` — 라이브 경기 데이터 조회
- **GET** `/api/mobile/live/games/{gameId}/events` — 라이브 이벤트 타임라인 조회

## 9. Standings API
리그 순위표

- **GET** `/api/standings` — 리그 순위표 조회

## Mobile. 선수 구독
마이페이지 LCK 선수 구독 관리 API

- **GET** `/api/mobile/me/player-subscriptions` — 내 구독 선수 목록 조회
- **POST** `/api/mobile/me/player-subscriptions` — 선수 구독 추가
- **GET** `/api/mobile/me/player-subscriptions/available-players` — 구독 가능한 2026 LCK 선수 검색
- **PUT** `/api/mobile/me/player-subscriptions/{playerId}` — 선수 알림 토글 변경
- **DELETE** `/api/mobile/me/player-subscriptions/{playerId}` — 선수 구독 해제

## 6. Home API
홈 화면용 데이터 제공 API (경기 일정, 커뮤니티, 뉴스, 챔피언/선수 통계)

- **GET** `/api/home/champion/top5` — 최근 패치 모스트 챔피언 TOP 5 조회
- **GET** `/api/home/community` — 커뮤니티 TOP 5 조회
- **GET** `/api/home/news` — 최신 뉴스 TOP 5 조회
- **GET** `/api/home/player/top5` — 최근 패치 선수 통계 TOP 5 조회
- **GET** `/api/home/schedule` — 경기 일정 조회 (날짜별)

## Mobile. 팀 알림 설정
마이페이지 팀별 알림 구독 설정 API

- **GET** `/api/mobile/me/notification-subscriptions` — 내 팀 알림 구독 목록 조회
- **POST** `/api/mobile/me/notification-subscriptions` — 팀 알림 구독 추가
- **GET** `/api/mobile/me/notification-subscriptions/available-teams` — 구독 가능한 LCK 팀 목록 조회
- **PUT** `/api/mobile/me/notification-subscriptions/{teamId}` — 팀별 알림 설정 변경
- **DELETE** `/api/mobile/me/notification-subscriptions/{teamId}` — 팀 알림 구독 삭제

## 4. 게임 기록 (상세)
특정 게임의 세부 전적, 밴픽, 인게임 지표를 조회합니다.

- **GET** `/api/games/{gameId}/record` — 게임 상세 데이터 조회

## 1.3 선수 관리
선수 정보 관리 API

- **GET** `/api/players/cards` — 선수 카드 목록 조회
- **DELETE** `/api/players/images` — 전체 선수 이미지 URL 초기화
- **GET** `/api/players/profile/{gameName}` — 선수 프로필 크롤링
- **POST** `/api/players/riot/manual-alert-check` — 선수 솔랭 알림 수동 체크
- **POST** `/api/players/riot/poll` — 선수 솔랭 감시 수동 실행
- **POST** `/api/players/riot/sync-primary-accounts` — LCK 선수 주 계정 Riot 식별자 동기화
- **POST** `/api/players/sync-images` — LCK 선수 이미지 URL 일괄 동기화
- **POST** `/api/players/sync-profiles` — LCK 선수 프로필 일괄 동기화
- **POST** `/api/players/{playerId}/image` — 선수 이미지 URL 수동 업데이트

## Mobile. 선수 평점
모바일 라이브 경기 선수 평점 및 한줄평 API

- **PUT** `/api/mobile/live/games/{gameId}/participants/{participantId}/my-rating` — 내 선수 평가 작성 또는 수정
- **DELETE** `/api/mobile/live/games/{gameId}/participants/{participantId}/my-rating` — 내 선수 평가 삭제
- **GET** `/api/mobile/live/games/{gameId}/participants/{participantId}/ratings` — 선수 평점 상세 및 리뷰 조회
- **GET** `/api/mobile/live/games/{gameId}/ratings` — 세트 선수 평점 목록 조회

## app-store-webhook-controller
- **POST** `/api/webhooks/appstore`

## backoffice-controller
- **GET** `/api/admin/cron-jobs`
- **GET** `/api/admin/league-configs`
- **PUT** `/api/admin/league-configs/{leagueName}`
- **GET** `/api/admin/leagues`
- **GET** `/api/admin/members`
- **GET** `/api/admin/members/{id}`
- **DELETE** `/api/admin/members/{id}`
- **GET** `/api/admin/notices`
- **POST** `/api/admin/notices`
- **POST** `/api/admin/notices/images`
- **GET** `/api/admin/notices/{id}`
- **PUT** `/api/admin/notices/{id}`
- **DELETE** `/api/admin/notices/{id}`
- **GET** `/api/admin/players`
- **POST** `/api/admin/players/solo-rank`
- **PUT** `/api/admin/players/{id}`
- **DELETE** `/api/admin/players/{id}`
- **POST** `/api/admin/players/{id}/image`
- **POST** `/api/admin/players/{id}/solo-rank-account`
- **GET** `/api/admin/ratings`
- **DELETE** `/api/admin/ratings/{id}`
- **GET** `/api/admin/riot-accounts/verify`
- **GET** `/api/admin/stats/notifications`
- **GET** `/api/admin/stats/overview`
- **GET** `/api/admin/stats/series`
- **GET** `/api/admin/subscriptions/matches`
- **GET** `/api/admin/subscriptions/matches/{matchId}/subscribers`
- **GET** `/api/admin/subscriptions/players`
- **GET** `/api/admin/subscriptions/players/{playerId}/subscribers`
- **GET** `/api/admin/subscriptions/teams`
- **GET** `/api/admin/subscriptions/teams/{teamId}/subscribers`
- **GET** `/api/admin/teams`
- **DELETE** `/api/admin/teams/{id}`

## kakao-skill-controller
- **GET** `/api/kakao/skills/images/matches/{matchId}.svg`
- **POST** `/api/kakao/skills/lck-schedule`
- **POST** `/api/kakao/skills/schedule`

## mobile-community-comment-controller
- **PUT** `/api/mobile/community/comments/{commentId}`
- **DELETE** `/api/mobile/community/comments/{commentId}`
- **POST** `/api/mobile/community/comments/{commentId}/like`
- **GET** `/api/mobile/community/posts/{postId}/comments`
- **POST** `/api/mobile/community/posts/{postId}/comments`

## mobile-community-moderation-controller
- **POST** `/api/mobile/community/blocks`
- **DELETE** `/api/mobile/community/blocks/{blockedMemberId}`
- **POST** `/api/mobile/community/reports`

## mobile-community-post-controller
- **GET** `/api/mobile/community/link-preview`
- **GET** `/api/mobile/community/posts`
- **POST** `/api/mobile/community/posts`
- **GET** `/api/mobile/community/posts/search`
- **GET** `/api/mobile/community/posts/{postId}`
- **PUT** `/api/mobile/community/posts/{postId}`
- **DELETE** `/api/mobile/community/posts/{postId}`
- **POST** `/api/mobile/community/posts/{postId}/like`
- **POST** `/api/mobile/community/posts/{postId}/notification`
- **POST** `/api/mobile/community/posts/{postId}/poll/vote`
- **POST** `/api/mobile/community/posts/{postId}/scrap`
- **POST** `/api/mobile/community/posts/{postId}/view`

## mobile-my-community-controller
- **GET** `/api/mobile/me/community/comments`
- **GET** `/api/mobile/me/community/likes`
- **GET** `/api/mobile/me/community/posts`
- **GET** `/api/mobile/me/community/scraps`
