// 서버 전용 공개 API.
//
// 왜 둘로 나누나: 한 슬라이스에 클라이언트 모듈과 서버 전용 모듈이 섞여 있는데
// `index.ts` 하나로 다 내보내면, **클라이언트 컴포넌트가 그 슬라이스를 import 하는
// 순간 서버 전용 사이드이펙트가 클라이언트 모듈 그래프로 번져** 빌드가 깨진다.
// FSD 공식 Next 가이드가 `index.server.ts` 를 권하는 이유다.
//
// 지금은 `PostBody` 가 서버 컴포넌트지만 이미지 탭·뷰어가 붙으면 클라이언트가 된다.
// 그때 `fetchPostDetail` 이 같이 끌려가지 않게 미리 갈라 둔다.

export {
  API_BASE_URL,
  API_HOST,
  DEFAULT_TIMEOUT_MS,
  getJson,
} from './client';
export type { RequestOptions } from './client';

export {
  SEARCH_MIN_LENGTH,
  fetchPostDetail,
  fetchPosts,
  searchPosts,
} from './community/index.server';
export { fetchNotices, fetchPromotedNotices } from './notice/index.server';
