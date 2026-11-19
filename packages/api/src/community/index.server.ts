import { API_BASE_URL, getJson, type RequestOptions, type Result } from '../client';
import { toCommentList, toPostDetail, toPostList } from './mappers';
import type { CommentList, PostDetail, PostList } from './types';

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

/**
 * 글의 댓글 목록.
 *
 * `GET /api/mobile/community/posts/{postId}/comments` — **비회원 조회가 열려
 * 있다**(실측 2026-11-19, HTTP 200).
 *
 * **오래된 순이다**(글 목록과 반대). 대화가 위에서 아래로 읽히게 하려는 것이라
 * 웹도 받은 순서를 그대로 그린다.
 *
 * 기본 50건인 것도 Dart 와 같다 — 댓글은 글보다 짧아 한 번에 많이 받아도
 * 부담이 적고, 대화가 중간에 끊기면 읽기 어렵다. 서버 상한은 100 이다.
 */
export function fetchComments(
  postId: number,
  { cursor, size = 50 }: { cursor?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<CommentList>> {
  const q = new URLSearchParams({ size: String(size) });
  if (cursor !== undefined) q.set('cursor', String(cursor));

  return getJson(
    `${API_BASE_URL}/mobile/community/posts/${postId}/comments?${q}`,
    toCommentList,
    options,
  );
}

/** 검색어 최소 길이. 이보다 짧으면 **서버가 400 을 준다**(실측 2026-11-19). */
export const SEARCH_MIN_LENGTH = 2;

/**
 * 커뮤니티 글 검색 — 제목·본문 키워드.
 *
 * `GET /api/mobile/community/posts/search` — 응답이 목록(`fetchPosts`)과
 * **같은 모양이다**(실측 2026-11-19: `posts`·`nextCursor`·`boardViewer`, 글
 * 필드 14개 동일). 그래서 `PostList` 타입과 매퍼를 그대로 쓴다.
 *
 * 비회원 조회가 열려 있다(HTTP 200).
 *
 * **짧은 검색어는 부르지 않는다.** 2자 미만이면 서버가 400 이라 호출 자체가
 * 낭비다 — 호출부가 [SEARCH_MIN_LENGTH] 로 거른다.
 */
export function searchPosts(
  {
    q,
    cursor,
    size = 20,
  }: { q: string; cursor?: number; size?: number },
  options: RequestOptions = {},
): Promise<Result<PostList>> {
  const params = new URLSearchParams({ q, size: String(size) });
  if (cursor !== undefined) params.set('cursor', String(cursor));

  return getJson(
    `${API_BASE_URL}/mobile/community/posts/search?${params}`,
    toPostList,
    options,
  );
}
