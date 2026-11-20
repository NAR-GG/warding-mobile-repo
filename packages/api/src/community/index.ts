// 클라이언트·서버 공용 공개 API — 타입과 순수 함수만.
// 서버 호출(`fetchPostDetail`)은 `index.server.ts` 에 있다.
//
// `export *` 를 쓰지 않는다. 무엇이 공개되는지 이 파일만 보고 알 수 있어야
// 하고, 내부 구현이 늘 때 조용히 새지 않는다.

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
} from './types';
export { isHeading } from './types';

export {
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
} from './mappers';
