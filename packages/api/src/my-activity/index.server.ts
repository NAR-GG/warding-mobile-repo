import { API_BASE_URL, getJson, type RequestOptions, type Result } from '../client';
import { toMyCommentPage, toMyPostPage, toScrapPage } from './mappers';
import type { MyCommentPage, MyPostPage, ScrapPage } from './types';

/**
 * 마이페이지 "내 활동" 조회 — `GET /api/mobile/me/community/{posts,comments,scraps}`.
 *
 * **셋 다 인증 필수다.** 커뮤니티 목록·공지와 달리 토큰 없이는 못 부른다 —
 * 호출부가 `token` 을 반드시 넘겨야 하고, 없으면 서버가 401 을 주고
 * `Result` 가 `unauthorized` 로 분류한다.
 *
 * **캐시하지 않는다**(`cache: 'no-store'` 를 호출부가 준다). 사용자마다 다른
 * 목록이라 공유 캐시에 담으면 남의 활동이 보인다 — 커뮤니티 상세에서
 * `viewer` 를 캐시하지 않는 것과 같은 이유다.
 *
 * 삭제·블라인드된 항목은 서버가 이미 걸러서 내려준다(Dart 주석과 같다).
 */

function meCommunityUrl(path: string, cursor?: number, size = 20): string {
  const q = new URLSearchParams({ size: String(size) });
  if (cursor !== undefined) q.set('cursor', String(cursor));
  return `${API_BASE_URL}/mobile/me/community/${path}?${q}`;
}

/** 내가 쓴 글 (최신순, 커서 = 글 id). */
export function fetchMyPosts(
  { cursor, size }: { cursor?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<MyPostPage>> {
  return getJson(meCommunityUrl('posts', cursor, size), toMyPostPage, options);
}

/** 내가 쓴 댓글 (최신순, 커서 = 댓글 id). 원글이 삭제된 댓글은 빠진다. */
export function fetchMyComments(
  { cursor, size }: { cursor?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<MyCommentPage>> {
  return getJson(
    meCommunityUrl('comments', cursor, size),
    toMyCommentPage,
    options,
  );
}

/** 내 스크랩 (최신순, 커서 = scrapId). */
export function fetchScraps(
  { cursor, size }: { cursor?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<ScrapPage>> {
  return getJson(meCommunityUrl('scraps', cursor, size), toScrapPage, options);
}
