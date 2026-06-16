# 평점·리뷰 전체 연동 설계

> 작성일 2026-06-16 · 대상 레포 `warding-mobile-repo` (Flutter) · 백엔드 `nar-back-repo`

## 1. 목표

경기상세 "선수 평점" 탭, 선수 평점 상세 화면, 마이페이지 "내 리뷰/평점"이 모두
목업 상태다. 백엔드(`nar`)에는 평점·리뷰 API가 이미 완성되어 있으므로, 세 화면을
MVVM 구조로 실데이터에 연동한다.

관련 이슈: [#15 선수 평점 탭 실데이터 연동](https://github.com/NAR-GG/warding-mobile-repo/issues/15)

## 2. 범위

- (A) 경기상세 "선수 평점" 탭 — 팀별 평균·선수별 평점 목록
- (B) 선수 평점 상세 화면 — KDA·평균·분포·내 평점·한줄평 리뷰 + 작성/수정/삭제
- (C) 마이페이지 "내 리뷰/평점" — 내가 쓴 평가 모아보기(날짜별 그룹·누적 건수·삭제)

**범위 밖**: 비회원 로컬 캐싱(이슈 #11), 라이브 자동 새로고침(이슈 #16). 평점은
세트 종료 후 정적이므로 폴링 없음.

## 3. 백엔드 API 계약 (이미 구현됨)

| 메서드 | 경로 | 인증 | 응답 |
|---|---|---|---|
| GET | `/api/mobile/live/games/{gameId}/ratings?teamSide=ALL` | optional | `LivePlayerRatingListResponse` |
| GET | `/api/mobile/live/games/{gameId}/participants/{participantId}/ratings?page&size` | optional | `LivePlayerRatingDetailResponse` |
| PUT | `/api/mobile/live/games/{gameId}/participants/{participantId}/my-rating` | **필수** | `MyRating` |
| DELETE | `/api/mobile/live/games/{gameId}/participants/{participantId}/my-rating` | **필수** | 204 |
| GET | `/api/mobile/me/ratings?page&size` | **필수** | `MyRatingListResponse` |

- 조회 2종은 `@AuthenticationPrincipal Long memberId` 가 nullable → 무토큰 호출 가능.
  토큰을 실어 보내면 응답의 `myRating`/`reviews[].mine` 이 채워진다.
- `rateable` 은 세트 종료 후 true (작성 가능 여부).
- 작성 본문: `{ rating: 1~5(필수), comment: ≤150자(선택) }`.

## 4. 인증 정책

**조회는 허용, 작성만 로그인 유도** (사용자 결정).

- 조회 GET 2종 → **optional-auth**: 토큰이 있으면 `Authorization` 헤더 첨부, 없으면
  무토큰으로 `http.get`. 토큰 없다고 throw 하지 않는다.
- 작성/수정/삭제 + `me/ratings` → 기존 `AuthService.authorizedRequest` 유지(토큰
  없으면 throw). View 는 이 throw 를 잡아 로그인 유도 처리한다.

## 5. 아키텍처 (접근 A — 승인됨)

경기상세 평점 탭 로드는 기존 `MatchDetailViewModel` 에 흡수(이미 `currentGameId`
소유 + 세트 전환 시 탭 리로드 → 챔피언픽·라이브이벤트와 동일한 "세트별 탭" 패턴).
독립 화면 2개는 새 ViewModel 을 둔다.

```
경기상세(MatchDetailViewModel)
  └ 선수 평점 탭 ── GameRatings ──┐
                                   │ 선수 행 탭 → Navigator.push
                                   ▼
            PlayerRatingScreen(PlayerRatingViewModel)  ← gameId, participantId, games
                                   ▲
마이페이지 → MyReviewScreen(MyReviewViewModel) ── '리뷰보기' → 같은 상세로 push
```

## 6. 데이터 계층 변경

### 6.1 `RatingRepository` (`lib/repository/rating/rating_repository.dart`)
- `_optionalAuthGet(url)` 헬퍼 추가: `AuthService.instance.jwt` 가 비어있지 않으면
  Bearer 헤더 첨부, 아니면 무토큰 GET.
- `fetchGameRatings` / `fetchPlayerRating` → `authorizedRequest` 대신
  `_optionalAuthGet` 사용. (401/HTML 만료 재시도는 토큰이 있을 때만 의미 있으므로,
  토큰 있는 경우엔 `authorizedRequest`, 없으면 무토큰 — 헬퍼 내부에서 분기.)
- `fetchMyRatings(page, size)` 신규 — `authorizedRequest` 로 `me/ratings` GET,
  `MyRatingList.fromJson`.
- `putMyRating` / `deleteMyRating` 변경 없음.

### 6.2 `ApiConfig` (`lib/config/api_config.dart`)
- `myRatingsUrl({int page=0, int size=20})` 추가 → `/mobile/me/ratings?page=&size=`.

### 6.3 신규 모델 `lib/model/my_rating_list.dart`
백엔드 `MyRatingListResponse` 매핑:
- `MyRatingList { List<MyRatingItem> ratings; int page,size,totalElements,totalPages; bool get hasMore; }`
- `MyRatingItem { ratingId, gameId, participantId, playerId, playerName, playerImageUrl,
  teamSide, role, championName, int rating, String? comment, DateTime createdAt/updatedAt, MatchInfo? match }`
- `MatchInfo { matchId, gameOrder, leagueName, matchTitle, blueTeamCode, redTeamCode, matchDate }`

기존 `lib/model/game_rating.dart` (`GameRatings`/`PlayerRatingDetail`/`Review` 등)는
백엔드 DTO 와 이미 일치 → 변경 없음.

## 7. ViewModel

### 7.1 `MatchDetailViewModel` 확장
- 상태 추가: `GameRatings? _ratings`, `bool _loadingRatings`, `String? _ratingsError`.
- getter: `ratings`, `loadingRatings`, `ratingsError`.
- `_loadCurrentSet()` 의 `Future.wait([...])` 에 `_loadRatings()` 추가 → 세트 진입/전환
  시 챔피언픽·라이브이벤트와 함께 평점도 로드. `selectSet` 에서 `_ratings = null` 초기화.
- `_loadRatings()`: `currentGameId` 로 `repo.fetchGameRatings(gameId)`. 실패 시
  `_ratingsError` 세팅(기존 탭들과 동일 패턴). gameId 미해석이면 빈 상태.

### 7.2 `PlayerRatingViewModel` (신규 `lib/viewmodel/player_rating/`)
- 생성자: `gameId`, `participantId`, `playerId`, `List<MatchGame> games`,
  `int currentSet`, `VoidCallback? onRequireLogin`.
- 상태: `PlayerRatingDetail? detail`, 누적 `reviews`, `loading`, `error`, `submitting`,
  `currentSet`, 페이지 커서.
- `load()` — 현재 (gameId, participantId) 상세 1페이지.
- `loadMoreReviews()` — `detail.hasMore` 면 다음 페이지를 누적.
- `selectSet(setNumber)` — 세트 전환: 해당 세트 gameId 로 `fetchGameRatings` →
  `playerId` 로 participantId 재해석 → 새 상세 로드. (게임마다 participantId 다름)
- `saveMyRating(rating, comment)` / `deleteMyRating()` — `authorizedRequest` throw 시
  `onRequireLogin()` 호출, 성공 시 상세 재로드(평균·분포·내평점 갱신).

### 7.3 `MyReviewViewModel` (신규 `lib/viewmodel/my_review/`)
- 상태: `List<MyRatingItem> items`, `loading`, `error`, 페이지 커서, `totalElements`(누적 건수).
- `load()` / `loadMore()` — `me/ratings` 페이지네이션.
- `Map<String, List<MyRatingItem>> get grouped` — `createdAt` 의 `YYYY.MM.DD` 로 그룹(최신순).
- `deleteRating(item)` — `repo.deleteMyRating(item.gameId, item.participantId)` 후 목록에서 제거.

## 8. View 연동

### 8.1 매핑 유틸 `lib/util/rating_mapping.dart` (신규)
- `BadgeSide sideFromTeamSide(String)` — `BLUE`→blue, `RED`→red.
- `String positionFromRole(String)` — `TOP/JUNGLE/MID/BOTTOM/SUPPORT` → `탑/정글/미드/원딜/서폿`.

### 8.2 경기상세 선수 평점 탭
- `match_detail_screen.dart`: `_tabIndex==2` 분기를 `ListenableBuilder` 로 감싸고
  `_viewModel.ratings` 사용. `GameRatings.players` 를 `teamSide` 로 분리하고
  각 `RatingPlayer` → `PlayerRating`(아래 필드 추가) 로 변환해 주입. 팀 평균/인원은
  `GameRatings.teams` 에서. 로딩/에러 상태 노출.
- `PlayerRating` (UI 값객체)에 `participantId`, `playerId`, `playerImageUrl` 필드 추가.
- `_openPlayerRating` 에서 `PlayerRatingScreen` 에 `gameId`(=currentGameId),
  `participantId`, `playerId`, `games`, `currentSet` 전달.

### 8.3 선수 평점 상세 화면 (`player_rating_screen.dart`)
- `StatefulWidget` 에서 `PlayerRatingViewModel` 생성·`load()`·`dispose`.
- KDA·분포·내 평점·한줄평 리뷰 목록을 VM 상태로 교체(TODO 6곳 제거).
- 세트 드롭다운 → `vm.selectSet`.
- 평점/코멘트 작성 시트 → `vm.saveMyRating`, 삭제 확인 → `vm.deleteMyRating`.
- `onRequireLogin` → 로그인 화면으로 이동(혹은 안내). 리뷰 더보기 → `loadMoreReviews`.

### 8.4 마이페이지 내 리뷰/평점 (`my_review_screen.dart`)
- `StatelessWidget` → `StatefulWidget` + `MyReviewViewModel`. mock `_groups` 제거.
- 누적 바 `count` ← `totalElements`. 날짜 그룹 ← `vm.grouped`.
- `ReviewCard` 입력을 `MyRatingItem` 기반으로(`MyReview` 값객체 매핑 또는 교체).
- '리뷰보기' → `PlayerRatingScreen`(item 의 gameId/participantId/playerId/match 기반).
- '리뷰삭제' → 확인 팝업 후 `vm.deleteRating`.

## 9. 에러·빈 상태

- 조회 실패: 각 화면에 에러 메시지 + 재시도(기존 라이브 탭 패턴 재사용).
- 빈 리뷰/평가: "아직 평가가 없어요" 류 빈 상태(기존 디자인 토큰 사용, 없으면 단순 텍스트).
- `rateable==false`: 작성 버튼 비활성/숨김 + 안내.
- 미로그인 작성 시도: `onRequireLogin` 로 로그인 유도.

## 10. 테스트

- ViewModel 단위 테스트(가짜 RatingRepository 주입): `PlayerRatingViewModel`
  로드/더보기/세트전환/save·delete, `MyReviewViewModel` 로드/그룹핑/삭제.
- Repository optional-auth 분기(토큰 유무) 동작.
- `flutter analyze` 통과(변경 파일).

## 11. 비고

- 기존 모델(`game_rating.dart`)이 DTO 와 일치해 모델 재작업이 거의 없다.
- `MatchDetailViewModel` 에 평점 로드를 흡수하므로 경기상세 화면은 VM 추가 구독 없이
  기존 `ListenableBuilder` 만으로 평점 탭을 갱신한다.
- DI 는 기존 방식(싱글턴 `RatingRepository.instance` 주입) 따른다.
