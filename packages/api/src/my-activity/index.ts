// 클라이언트·서버 공용 공개 API — 타입과 순수 함수만.
// 서버 호출은 `index.server.ts` 에 있다.

export type {
  MyComment,
  MyCommentPage,
  MyPostPage,
  ScrapItem,
  ScrapPage,
} from './types';

export {
  toMyComment,
  toMyCommentPage,
  toMyPostPage,
  toScrapItem,
  toScrapPage,
} from './mappers';
