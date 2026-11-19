import { API_BASE_URL, getJson, type RequestOptions, type Result } from '../client';
import { toPostDetail, toPostList } from './mappers';
import type { PostDetail, PostList } from './types';

/**
 * 커뮤니티 글 상세.
 *
 * `GET /api/mobile/community/posts/{postId}` — Flutter `ApiConfig.communityPostUrl`
 * 과 같은 경로다.
 *
 * **비회원도 조회할 수 있다**(실측 2026-11-17, HTTP 200). SSR 이 성립하는
 * 근거가 이것이다 — 서버가 토큰 없이도 본문을 그릴 수 있다.
 *
 * 비회원이어도 `viewer` 는 객체로 온다(전부 false). 화면은 로그인 여부를
 * 따로 알고 버튼 노출을 정한다.
 */
export function fetchPostDetail(
  postId: number,
  options: RequestOptions = {},
): Promise<Result<PostDetail>> {
  return getJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}`,
    toPostDetail,
    options,
  );
}

/**
 * 커뮤니티 글 목록.
 *
 * `GET /api/mobile/community/posts` — **비회원 조회가 열려 있다**
 * (실측 2026-11-19, HTTP 200). 커서 기반이라 글이 추가돼도 목록이 밀리지 않는다.
 *
 * `boardTeamId` 를 주면 그 팀 게시판, 없으면 전체다.
 */
export function fetchPosts(
  {
    cursor,
    size = 20,
    boardTeamId,
  }: { cursor?: number; size?: number; boardTeamId?: number } = {},
  options: RequestOptions = {},
): Promise<Result<PostList>> {
  const q = new URLSearchParams({ size: String(size) });
  if (cursor !== undefined) q.set('cursor', String(cursor));
  if (boardTeamId !== undefined) q.set('boardTeamId', String(boardTeamId));

  return getJson(
    `${API_BASE_URL}/mobile/community/posts?${q}`,
    toPostList,
    options,
  );
}
