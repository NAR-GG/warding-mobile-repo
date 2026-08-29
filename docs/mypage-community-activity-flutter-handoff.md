# 마이페이지 커뮤니티 내 활동 — 플러터 작업 요청서

마이페이지에서 내가 커뮤니티에 남긴 것들(쓴 글·쓴 댓글·스크랩)을 다시 찾아보는 기능입니다.
**백엔드·Repository·모델은 전부 끝났고 화면만 없습니다.**

| | |
|---|---|
| 백엔드 | 완료 (`nar-back-repo` #483·#491·#495) |
| Repository | 완료 — `CommunityActivityRepository` 4종 |
| 모델 | 완료 — `community_my_activity.dart`, `community_remote_post.dart` |
| 남은 것 | ViewModel · 화면 · 마이페이지 진입점 · 문구 |
| 예상 | 1.5~2일 |

지금 `fetchMyPosts`·`fetchMyComments`·`fetchScraps`·`fetchMyLikes` 의 **호출처가 리포지토리
파일 자기 자신뿐**입니다. API가 다 있는데 사용자에게 보이는 곳이 하나도 없는 상태입니다.

---

## 먼저 읽어주세요

### 1. 건수(count)를 넣지 않습니다

`MypageCardItem` 에 `count` 슬롯이 있고 기존 "내 리뷰/평점" 항목은 숫자를 보여줍니다.
그건 리뷰 API가 페이지 기반이라 `totalElements` 가 오기 때문입니다.

**커뮤니티 내 활동 4종은 전부 커서 페이지네이션이라 총 건수가 없습니다.** 백엔드에 건수 API도
없고, 이번에 만들지 않기로 했습니다. `count` 는 nullable이니 **넘기지 마세요.**
리뷰 항목만 숫자가 있고 커뮤니티 항목은 비는 모양이 됩니다 — 의도된 것입니다.

### 2. 게시판 구분은 `boardTeamCode` 로 합니다 (팀 목록 조회 금지)

목록에 전체 게시판 글과 팀 게시판 글이 **섞여서** 내려옵니다. 줄마다 배지가 필요합니다.

기존 커뮤니티 목록 화면은 `boardTeamId` 를 `communityTeams`(온보딩 팀 API)에 매핑해 이름을
얻습니다. **내 활동에서는 그러지 마세요.** 그 조회가 실패하면 목록 화면은 부제 하나가 비는
정도지만, 내 활동은 줄마다 붙는 게시판 구분이 통째로 사라집니다.

서버가 `boardTeamCode` 를 같이 내려줍니다. 그걸 쓰세요.

### 3. `boardTeamCode` 는 작성자 응원팀이 아닙니다

`author.teamCode` 와 헷갈리기 쉬운데 다른 값입니다. 다른 팀 게시판 글에도 댓글을 달 수 있어서
`boardTeamCode: "GEN"` 인데 `author.teamCode: "T1"` 인 행이 정상적으로 존재합니다.

배지에 써야 하는 건 **`boardTeamCode`(글이 있는 게시판)** 입니다.

### 4. 내 댓글은 `postId` 로 원글에 들어갑니다

`MyCommentResponse` 에는 원글 제목(`postTitle`)만 있고 본문·작성자·썸네일이 없습니다.
탭했을 때는 `postId` 로 `PostDetailScreen` 을 엽니다. 원글이 삭제·블라인드되면 서버가 목록에서
빼주므로 **`postId` 는 항상 유효한 이동 대상**입니다.

### 5. 상세 헤더 오버플로 버그가 먼저 고쳐져야 합니다

`NarDetailHeader` 의 기본 분기(`centerTitle: true`)에 `maxLines`·`overflow`·폭 제한이
없습니다(`lib/components/nar_detail_header.dart:77`). `centerTitle: false` 분기에는 제대로
있는데 기본값 쪽만 빠져 있습니다.

이 화면도 같은 헤더를 쓰므로 제목이 길면 뒤로가기·우측 슬롯 위로 글자가 넘어갑니다.
**별도 이슈로 먼저 고치고 시작하는 걸 권합니다** — 경기 상세·선수 평점·구독 설정·온보딩이
전부 이 컴포넌트를 씁니다.

---

## 범위 — 3종 먼저, 좋아요는 나중

| 항목 | 1차 | 이유 |
|---|---|---|
| 내가 쓴 글 | ✅ | 자기 글 관리는 커뮤니티 기본 |
| 내가 쓴 댓글 | ✅ | 어디에 뭘 남겼는지 되찾는 수요가 분명 |
| 스크랩 | ✅ | "나중에 볼 글"이라 다시 찾는 동기가 명확 |
| 좋아요한 글 | ⏸ | API·모델 다 있지만 다시 찾을 동기가 약함. 화면만 늘어남 |

좋아요는 **글·스크랩과 완전히 같은 위젯**(`PostListItem`)이라 나중에 탭 하나 추가하는 비용이
사실상 0입니다. 필요해지면 그때 넣으면 됩니다. 처음부터 4개를 깔 이유는 없습니다.

---

## API

전부 인증 필수, 최신순, 커서 페이지네이션입니다. `size` 기본 20.
`ApiConfig.meCommunity*Url(cursor:, size:)` 로 URL이 이미 만들어져 있습니다.

| 화면 | 메서드 | 커서 | 반환 |
|---|---|---|---|
| 내 글 | `fetchMyPosts` | `nextCursor` (글 id) | `CommunityRemotePostPage` |
| 내 댓글 | `fetchMyComments` | `nextCursor` (댓글 id) | `CommunityMyCommentPage` |
| 스크랩 | `fetchScraps` | `nextCursor` (**scrapId**) | `CommunityScrapPage` |
| 좋아요 | `fetchMyLikes` | `nextCursor` (**likeId**) | `CommunityLikePage` |

⚠️ 스크랩·좋아요의 커서는 **글 id가 아니라 scrapId/likeId** 입니다. 항목이
`{scrapId, post}` / `{likeId, post}` 로 한 겹 감싸여 오는 것도 그래서입니다.
글 id로 커서를 넘기면 페이지가 어긋납니다.

`nextCursor` 가 null이면 마지막 페이지입니다.

삭제·블라인드된 글/댓글은 **서버가 이미 걸러서** 내려줍니다. 앱에서 거를 필요 없습니다.

### 행에 쓸 필드

**글·스크랩·좋아요** (`CommunityRemotePost`)
```
id · boardTeamId · boardTeamCode · title · bodyPreview · author
viewCount · likeCount · commentCount · edited · createdAt · thumbnailUrl · imageCount
```

**내 댓글** (`CommunityMyComment`)
```
id · postId · postTitle · boardTeamId · boardTeamCode · body · likeCount · createdAt
```

---

## 화면

### 진입점 — 마이페이지 "내 활동" 섹션

`lib/screens/mypage/mypage_screen.dart` 의 `MypageCardSection(label: myActivity)` 에
항목 3개를 추가합니다. 주석에 적힌 대로 `items` 에 `MypageCardItem` 만 넣으면 됩니다.

```
내 활동
  내 리뷰/평점        12      ← 기존
  내가 쓴 글                  ← 신규 (count 없음)
  내가 쓴 댓글                ← 신규
  스크랩                      ← 신규
```

각 항목은 **같은 화면**을 열고 초기 탭만 다르게 줍니다. 화면 3개를 만들지 마세요.

### 화면 구조

기존 커뮤니티 화면과 같은 뼈대입니다.

```
NarDetailHeader(title: '내 활동')
NarTabBar(tabs: ['내 글', '내 댓글', '스크랩'])   ← variant 는 커뮤니티 화면과 맞춤
RefreshIndicator
  └ ListView.builder  (하단 200px 전에 다음 페이지 요청)
      ├ 행 …
      └ 마지막에 CircularProgressIndicator (loadingMore)
비었을 때: _Empty 와 같은 형태의 안내 문구
```

탭마다 스크롤 위치와 커서가 따로 있어야 합니다. 커뮤니티의 `_BoardList` 가 `ScrollController`
를 각자 드는 것과 같은 이유입니다.

### 행 구성

**글·스크랩** — `PostListItem` 을 그대로 씁니다. 배지만 얹으면 됩니다.

**내 댓글** — 신규 위젯이 필요합니다. `comment_tile.dart` 는 상세 화면용(멘션·답글·좋아요
토글)이라 맞지 않습니다. 구조는 이렇게:

```
[배지] 원글 제목                     ← 탭하면 postId 로 상세 이동
내가 쓴 댓글 본문 (2줄, ellipsis)
3시간 전 · 좋아요 2
```

---

## 배지

`boardTeamCode` 로만 그립니다.

| 값 | 배지 |
|---|---|
| `boardTeamCode == null` | `전체` |
| `boardTeamCode == 'GEN'` | `GEN` |

폴백 — 서버 배포 전이거나 구버전 응답이면 `boardTeamCode` 가 없을 수 있습니다.
`boardTeamId != null && boardTeamCode == null` 이면 **배지를 그리지 않습니다.**
팀 목록을 조회하러 가지 마세요(먼저 읽어주세요 2번).

스타일 — 새 컴포넌트 하나 만들고 세 화면이 공유합니다. 기존 토큰만 씁니다:

```
배경   AppColors.narDark500
글자   AppColors.narText3
테두리 AppColors.narLine
폰트   Pretendard w600, 10~11 * scale
모양   radius 4, 가로 패딩 6 * scale, 세로 2 * scale
```

팀 로고를 배지에 넣지 마세요. 작성자 옆 `TeamLogoDot`(응원팀)과 시각적으로 충돌합니다.
게시판은 **글자**, 작성자 응원팀은 **원형 로고** 로 역할을 나눕니다.

---

## 문구 (l10n)

`lib/l10n/app_ko.arb` / `app_en.arb` 양쪽에 추가합니다. 지금은 `communityScrap`("스크랩")
하나만 있습니다.

| 키 | 한국어 | 쓰는 곳 |
|---|---|---|
| `myCommunityActivity` | 내 활동 | 화면 제목 |
| `myCommunityPosts` | 내가 쓴 글 | 카드 항목·탭 |
| `myCommunityComments` | 내가 쓴 댓글 | 카드 항목·탭 |
| `communityScrap` | 스크랩 | *(이미 있음)* |
| `communityBoardAll` | 전체 게시판 | *(이미 있음 — 배지는 "전체"만 쓰므로 별도 키 필요)* |
| `myCommunityBadgeAll` | 전체 | 배지 |
| `myCommunityPostsEmpty` | 아직 쓴 글이 없어요 | 빈 상태 |
| `myCommunityCommentsEmpty` | 아직 쓴 댓글이 없어요 | 빈 상태 |
| `communityScrapEmpty` | 스크랩한 글이 없어요 | 빈 상태 |

---

## 에러 처리

리포지토리가 2xx가 아니면 `CommunityApiException` 을 던지고 Sentry에 warning을 남깁니다.
화면에서는 기존 커뮤니티 화면과 같게 처리하면 됩니다.

**비회원 진입은 막아주세요.** 4종 모두 인증 필수라 토큰이 없으면 401입니다. 마이페이지 자체가
로그인 뒤 화면이라 정상 경로에서는 안 생기지만, 토큰 만료 시 `authorizedRequest` 의 재발급이
실패하면 도달할 수 있습니다.

---

## 체크리스트

- [ ] `NarDetailHeader` `centerTitle: true` 오버플로 수정 (선행, 별도 PR 권장)
- [ ] 배지 위젯 신규 (`boardTeamCode` → 전체 / 팀 코드)
- [ ] 내 댓글 행 위젯 신규
- [ ] 내 활동 ViewModel — 탭 3개의 커서·로딩·에러 상태를 따로 든다
- [ ] 내 활동 화면 — 헤더 + `NarTabBar` + 무한 스크롤 + 당겨서 새로고침
- [ ] 마이페이지 `MypageCardSection` 에 항목 3개 추가 (**`count` 안 넘김**)
- [ ] l10n 키 추가 (ko/en)
- [ ] 글·스크랩은 `PostListItem` 재사용, 탭 시 `postId` 로 상세 이동
- [ ] 스크랩 커서가 `scrapId` 인지 확인 (글 id 아님)
- [ ] `boardTeamCode` 없을 때 배지 생략되는지 확인

---

## 참고

| | |
|---|---|
| 선례 화면 | `lib/screens/my_review/my_review_screen.dart` (236줄) |
| 목록·무한스크롤 선례 | `lib/screens/community/community_screen.dart` 의 `_BoardList` |
| 재사용 위젯 | `lib/screens/community/component/post_list_item.dart` |
| 진입점 | `lib/screens/mypage/mypage_screen.dart` 의 `MypageCardSection` |
| 백엔드 응답 정의 | `nar-back-repo` `CommunityDtos.java` |
