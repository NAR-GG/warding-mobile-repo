# 커뮤니티 API 연동 — 1단계: 모델 + Repository 기반 설계

> 작성일 2026-08-28 · 대상 레포 `warding-mobile-repo` (Flutter) · 백엔드 `nar-back-repo`

## 1. 목표

커뮤니티 화면(`screens/community/*`)은 전부 `community_dummy.dart` 하드코딩
데이터로 그려지고 있고, ViewModel/Repository 계층이 없다. 백엔드는 커뮤니티
1~4단계(게시글 8·댓글 4·신고차단 3·내활동 4·사진서명 1 = 총 20개 엔드포인트)를
prod(`https://api.nar.kr`)에 이미 배포했다.

전체 작업은 6개 하위 프로젝트로 나눠 진행한다 (①모델+Repository → ②피드+상세
→ ③쓰기 액션 → ④댓글 → ⑤신고·차단 → ⑥내 활동 신규 화면). 이 문서는 **① 모델 +
Repository 기반**만 다룬다.

## 2. 범위

- 커뮤니티 API 20개 전체를 호출하는 Repository 계층
- API 응답을 담는 모델(`fromJson`) 및 요청 파라미터
- 서버 에러 코드·`Retry-After` 헤더를 구조화해 던지는 공통 예외 타입
- Repository 단위 테스트 (`MockClient`)

**범위 밖 (non-goals)**
- ViewModel, 화면 와이어링 — 다음 단계들에서.
- `community_dummy.dart`와 이를 쓰는 현재 화면들은 **손대지 않는다**. main 브랜치는
  이 단계가 끝난 뒤에도 지금 그대로 컴파일된다.
- 마이페이지 "내 활동" 진입점 UI — ⑥ 단계에서.
- 투표 API, 규칙 전문 API(D-6) — 서버에 아직 없음.

## 3. 모델 네이밍 — 더미 모델과의 공존

기존 더미 모델 `CommunityPost`/`CommunityComment`(`lib/model/community_post.dart`,
`lib/model/community_comment.dart`)는 API 응답과 필드가 크게 다르다
(`timeAgo` 문자열 vs `createdAt` DateTime, `authorName+authorTeamId` vs `author`
객체 등). 이름이 겹치면 더미 화면들이 즉시 깨지므로, 새 API 모델은 **`Remote`
접두어**로 구분해 별도 파일에 둔다. 더미 파일·화면이 사라지는 ②단계에서 이름을
정리(Remote 접두어 제거)할 수 있다 — 지금은 하지 않는다.

이름이 겹치지 않는 모델(`CommunityAuthor`, `CommunityBoardViewer`,
`CommunityPostImage`, 신고·내활동 관련)은 접두어 없이 그대로 둔다.

## 4. 공통 에러 처리

`lib/repository/community/community_api_exception.dart`:

```
class CommunityApiException implements Exception {
  final int statusCode;
  final String? code;       // 예: COMMUNITY_TEAM_COOLDOWN
  final String message;
  final int? retryAfterSeconds; // Retry-After 헤더, 없으면 null

  factory CommunityApiException.fromResponse(http.Response response) { ... }
}
```

`fromResponse`는 body를 `jsonDecode` 시도해 `code`/`message`를 꺼내고(실패하면
`message = 'HTTP $statusCode'`), `response.headers['retry-after']`를
`int.tryParse`한다. 커뮤니티 계열 3개 Repository(`community_repository.dart`,
`community_report_repository.dart`, `community_activity_repository.dart`)가
2xx가 아니면 전부 이 예외를 던진다. `community_image_repository.dart`는
`ProfileImageRepository`와 동일하게 일반 `Exception`을 유지한다(사진 서명
엔드포인트는 구조화된 커뮤니티 에러 코드 대상이 아님).

이후 단계에서 ViewModel은 `catch (e) { if (e is CommunityApiException) switch
(e.code) { ... } }` 형태로 문구를 분기한다(이 문서 범위 밖).

## 5. 모델

전부 `lib/model/`에 flat하게 (파일 생성 규칙). 시간 필드는 `notice.dart` 관례대로
`DateTime`으로 파싱하고, "N분 전" 표기 계산은 화면 쪽 몫으로 남긴다(모델에
고정 문자열로 박지 않음 — 그래야 화면에 떠 있는 동안 재계산된다).

- **`community_author.dart`** — `CommunityAuthor { memberId, nickname,
  profileImageUrl, teamId?, teamCode?, teamImageUrl? }`. 글/댓글 응답에서
  `author`가 없으면(탈퇴 회원) 상위 모델 필드가 `CommunityAuthor?`로 null.
- **`community_remote_post.dart`**
  - `CommunityRemotePost` — 목록 요약: `id, boardTeamId?, title, bodyPreview,
    author?, viewCount, likeCount, commentCount, edited, createdAt,
    thumbnailUrl?, imageCount`.
  - `CommunityRemotePostDetail` — `CommunityRemotePost`의 전체 필드 +
    `body, images: List<CommunityPostImage>, viewer: CommunityPostViewer`.
    `viewer.blockedAuthor==true`면 `title/body/images`가 빈 값으로 온다(그대로
    보존, 화면에서 가림 처리는 다음 단계).
  - `CommunityBoardViewer { canWrite, reason: CommunityWriteLockReason?
    (NOT_FAN/COOLDOWN), writableFrom: DateTime? }`.
  - `CommunityRemotePostPage { posts: List<CommunityRemotePost>, nextCursor:
    int?, boardViewer: CommunityBoardViewer? }` — 팀 게시판+로그인일 때만
    `boardViewer`가 옴, 그 외 null.
- **`community_post_image.dart`** — `CommunityPostImage { id, url }` (상세
  이미지, 신고 targetId로 재사용).
- **`community_remote_comment.dart`**
  - `CommunityCommentStatus` enum — `VISIBLE, DELETED, BLOCKED, HIDDEN`.
  - `CommunityRemoteComment { id, parentId?, body?, status, author?,
    mentionNickname?, likeCount, liked, mine, createdAt }` — status가
    VISIBLE이 아니면 `body`/`author`가 null로 온다(자리 보존).
  - `CommunityRemoteCommentPage { comments, nextCursor: int? }`.
- **`community_report.dart`** — `CommunityReportTargetType` enum
  (POST/COMMENT/IMAGE), `CommunityReportReason` enum
  (ABUSE/OBSCENE/AD/FRAUD/SPAM/ETC).
- **`community_my_activity.dart`**
  - `CommunityScrapItem { scrapId, post: CommunityRemotePost }`,
    `CommunityScrapPage { items, nextCursor: int? }`.
  - `CommunityLikeItem { likeId, post: CommunityRemotePost }`,
    `CommunityLikePage { items, nextCursor: int? }`.
  - `CommunityMyComment { id, postId, postTitle, body, likeCount, createdAt }`,
    `CommunityMyCommentPage { comments, nextCursor: int? }`.

## 6. Repository

기존 `RatingRepository`/`ProfileImageRepository` 패턴(싱글턴 `instance`,
`AuthService.instance`, GET은 `_optionalAuthGet`, 쓰기는
`_auth.authorizedRequest`, `debugPrint('[Tag] ...')`, `SentryLogger` 경고)을
그대로 따른다.

### 6.1 `repository/community/community_repository.dart` — 게시글 8 + 댓글 4

| 메서드 | 엔드포인트 | 인증 |
|---|---|---|
| `fetchPosts({boardTeamId?, cursor?, size=20})` → `CommunityRemotePostPage` | `GET /api/mobile/community/posts` | optional |
| `fetchPostDetail(postId)` → `CommunityRemotePostDetail` | `GET .../posts/{id}` | optional |
| `createPost({boardTeamId?, title, body, imageUrls=[]})` → `int id` | `POST .../posts` | 필수 |
| `updatePost(postId, {boardTeamId?, title, body, imageUrls?})` | `PUT .../posts/{id}` | 필수 |
| `deletePost(postId)` | `DELETE .../posts/{id}` | 필수 |
| `markPostViewed(postId)` | `POST .../posts/{id}/view` | optional (204, 응답 무시) |
| `toggleLike(postId)` → `(liked, likeCount)` | `POST .../posts/{id}/like` | 필수 |
| `toggleScrap(postId)` → `bool scrapped` | `POST .../posts/{id}/scrap` | 필수 |
| `fetchComments(postId, {cursor?, size=50})` → `CommunityRemoteCommentPage` | `GET .../posts/{postId}/comments` | optional |
| `createComment(postId, {body, replyToCommentId?})` → `int id` | `POST .../posts/{postId}/comments` | 필수 |
| `deleteComment(commentId)` | `DELETE .../comments/{id}` | 필수 |
| `toggleCommentLike(commentId)` → `(liked, likeCount)` | `POST .../comments/{id}/like` | 필수 |

답글은 `replyToCommentId`에 **대상 댓글 id를 그대로** 넘긴다 — parent 계산은
서버가 한다(가이드 문서 그대로).

### 6.2 `repository/community/community_report_repository.dart` — 3

| 메서드 | 엔드포인트 |
|---|---|
| `report({targetType, targetId, reason, detail?})` | `POST /api/mobile/community/reports` (204) |
| `block(memberId)` | `POST /api/mobile/community/blocks` (204, 멱등) |
| `unblock(memberId)` | `DELETE /api/mobile/community/blocks/{memberId}` (멱등) |

### 6.3 `repository/community/community_activity_repository.dart` — 4 (전부 인증 필수)

| 메서드 | 엔드포인트 |
|---|---|
| `fetchScraps({cursor?, size=20})` → `CommunityScrapPage` | `GET /api/mobile/me/community/scraps` |
| `fetchMyPosts({cursor?, size=20})` → `CommunityRemotePostPage` | `GET /api/mobile/me/community/posts` |
| `fetchMyLikes({cursor?, size=20})` → `CommunityLikePage` | `GET /api/mobile/me/community/likes` |
| `fetchMyComments({cursor?, size=20})` → `CommunityMyCommentPage` | `GET /api/mobile/me/community/comments` |

### 6.4 `repository/community/community_image_repository.dart` — 사진 서명 업로드 1

`ProfileImageRepository`와 동일 구조(서명 발급 → Cloudinary multipart 업로드 →
`secure_url` 반환)로 별도 클래스를 둔다. 서명 응답 필드가 프로필과 다르고
(`cloudName` 포함, `public_id` 매번 새로 발급) 사용처가 둘뿐이라 공통
추상화는 만들지 않는다.

- `upload(File file)` → `Future<String> secureUrl`
- 내부: `POST /api/auth/me/community-image/signature`(인증) → Cloudinary
  `uploadUrl`로 multipart(`public_id/timestamp/signature/api_key/overwrite`).

## 7. `ApiConfig` 추가

`lib/config/api_config.dart`에 기존 스타일(static 메서드, 쿼리 스트링 직접
조립)로 20개 엔드포인트 URL 빌더를 추가한다: `communityPostsUrl`,
`communityPostUrl`, `communityPostViewUrl`, `communityPostLikeUrl`,
`communityPostScrapUrl`, `communityCommentsUrl`, `communityCommentUrl`,
`communityCommentLikeUrl`, `communityReportsUrl`, `communityBlocksUrl`,
`communityBlockUrl`, `meCommunityScrapsUrl`, `meCommunityPostsUrl`,
`meCommunityLikesUrl`, `meCommunityCommentsUrl`, `communityImageSignatureUrl`.

## 8. 테스트

- `test/repository/community/community_repository_test.dart`,
  `community_report_repository_test.dart`, `community_activity_repository_test.dart`,
  `community_image_repository_test.dart` — `MockClient` +
  `setApiClientForTesting`로 URL·HTTP 메서드·인증 헤더 유무·성공 파싱을 검증하고,
  `CommunityApiException`이 `code`/`retryAfterSeconds`를 제대로 담는지
  (`COMMUNITY_TEAM_COOLDOWN`, `COMMUNITY_WRITE_INTERVAL` 최소 1건씩) 확인한다.
- `test/model/community_remote_post_test.dart`,
  `test/model/community_remote_comment_test.dart` — `author==null`(탈퇴 회원),
  `boardViewer` 유무, `CommunityCommentStatus`별 body/author null 분기 등
  fromJson 경계값.
- `flutter analyze` 통과(변경 파일).

## 9. 구현 전 Swagger 확인 필요

가이드 문서에 응답 예시가 없거나 애매한 지점 2곳은 구현 착수 시
`https://api.nar.kr/swagger-ui.html`로 먼저 확인한다(가이드 문서 자체가 "궁금한
응답 형태는 Swagger가 최신"이라고 명시함):

1. **댓글 작성 응답 바디** — 글 작성(`POST .../posts`)은 `{ "id": 43 }`가
   명시돼 있지만 댓글 작성(`POST .../comments`)은 예시가 없다. 이 문서는 글과
   동일하게 `{ "id": ... }`로 가정했다. 다르면 `createComment` 반환 타입만
   조정하면 되고 다른 설계에는 영향 없음.
2. **`boardViewer`가 실리는 위치** — 목록 응답 예시(`{ posts, nextCursor }`)와
   잠금 바 예시(`{ canWrite, reason, writableFrom }`)가 별도 블록으로 나와
   있어, 이 문서는 `boardViewer`를 목록 응답의 형제 키로 가정했다
   (`CommunityRemotePostPage.boardViewer`). 실제로 다른 위치(예: 게시글별)면
   `CommunityRemotePostPage`만 조정.

## 10. 다음 단계와의 연결

- ② 피드+상세 단계에서 `community_screen.dart`/`post_detail_screen.dart`를
  `CommunityRepository` 기반 ViewModel로 전환하면서 `community_dummy.dart`와
  더미 `CommunityPost`/`CommunityComment`를 삭제하고, 그 시점에 `Remote` 접두어
  모델을 정리(이름에서 `Remote` 제거)할 수 있다 — 이 문서에서 결정하지 않는다.
- ③~⑥ 단계는 각각 쓰기 액션, 댓글, 신고·차단, 내 활동 화면을 이 Repository 위에
  얹는다. 이번 단계에서 만든 메서드 시그니처를 그대로 소비할 수 있어야 한다.
