// 클라이언트·서버 공용 공개 API — 타입과 순수 함수만.
// 서버 호출(`fetchPostDetail`)은 `index.server.ts` 에 있다.
//
// `export *` 를 쓰지 않는다. 무엇이 공개되는지 이 파일만 보고 알 수 있어야
// 하고, 내부 구현이 늘 때 조용히 새지 않는다.

export type {
  Author,
  Poll,
  PollOption,
  PostBlock,
  PostDetail,
  PostImage,
  PostViewer,
} from './types';
export { isHeading } from './types';

export {
  parseBlocks,
  toAuthor,
  toPoll,
  toPollOption,
  toPostBlock,
  toPostDetail,
  toPostImage,
  toPostViewer,
} from './mappers';
