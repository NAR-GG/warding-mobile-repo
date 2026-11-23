// 웹이 NAR 백엔드를 부르는 클라이언트.
//
// **설계 전제 3가지** (→ 웹뷰 전환 spec 의 Decisions):
//
// 1. **웹이 직접 부른다.** 브리지로 Flutter repository 를 거치지 않는다. 그
//    경로면 서버가 데이터를 몰라 SSR 로 그릴 게 없고, 응답 필드가 늘 때마다
//    Flutter 를 고쳐야 해서 "심사 없이 배포" 와 어긋난다.
// 2. **토큰은 스스로 갖지 않는다.** 네이티브 Keychain 에 있는 것을 브리지로
//    받아 호출부가 `options.token` 으로 넘긴다. 비회원 조회가 열린
//    엔드포인트는 토큰 없이 부른다 — SSR 첫 페인트가 거기에 기댄다.
// 3. **실패를 던지지 않는다.** `Result<T>` 로 돌려 호출부가 분기를 빠뜨리면
//    타입에서 걸리게 한다(Flutter 의 `Either<Failure, T>` 와 같은 계약).
//
// **이 파일은 클라이언트에서도 안전한 것만 내보낸다** — 타입과 순수 함수다.
// 서버 호출은 `index.server.ts` 에 있고 `server-only` 가 걸려 있다.

export {
  err,
  failureFromStatus,
  networkFailure,
  noDataFailure,
  ok,
  parseFailure,
  serverFailure,
  toFailure,
  unauthorizedFailure,
} from './failure';
export type { Failure, FailureKind, Result } from './failure';

export {
  isHeading,
  parseBlocks,
  toAuthor,
  toComment,
  toCommentList,
  toPoll,
  toPollOption,
  toPostBlock,
  toPostDetail,
  toPostImage,
  toPostList,
  toPostSummary,
  toPostViewer,
} from './community';
export type {
  Author,
  Comment,
  CommentList,
  CommentStatus,
  Poll,
  PollOption,
  PostBlock,
  PostDetail,
  PostImage,
  PostList,
  PostSummary,
  PostViewer,
  UploadSignature,
} from './community';

export { toNotice, toNoticePage } from './notice';
export type { Notice, NoticePage } from './notice';

export {
  toMyComment,
  toMyCommentPage,
  toMyPostPage,
  toScrapItem,
  toScrapPage,
} from './my-activity';
export type {
  MyComment,
  MyCommentPage,
  MyPostPage,
  ScrapItem,
  ScrapPage,
} from './my-activity';
export {
  hasMore,
  toMyRating,
  toMyReviewItem,
  toMyReviewPage,
  toPlayerRatingDetail,
  toRatedMatch,
  toRatingDistribution,
  toRatingPlayerDetail,
  toReview,
} from './rating';
export type {
  MyRating,
  MyReviewItem,
  MyReviewPage,
  PlayerRatingDetail,
  RatedMatch,
  RatingDistribution,
  RatingPlayerDetail,
  Review,
} from './rating';
export {
  championName,
  gameDurationSeconds,
  isCommunityType,
  isSoloRankEnd,
  kda,
  playerName,
  postId,
  queueType,
  soloRankWin,
  toMemberNotification,
  toNotificationPage,
  toNotificationType,
} from './notification';
export type {
  MemberNotification,
  NotificationPage,
  NotificationType,
} from './notification';
