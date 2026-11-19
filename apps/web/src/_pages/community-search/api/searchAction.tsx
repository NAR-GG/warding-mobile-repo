'use server';

import type { ReactNode } from 'react';
import { SEARCH_MIN_LENGTH, searchPosts } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';
import { PostCard } from '@/shared/ui';

export type SearchPage = {
  /** 서버가 그린 결과 항목. 데이터가 아니라 JSX 다(→ 아래 주석). */
  items: ReactNode;
  /** 이번 페이지에 담긴 글 id. 다음 페이지 중복을 거르는 데 쓴다. */
  ids: number[];
  nextCursor: number | null;
};

/**
 * 검색 결과 한 페이지.
 *
 * **JSX 를 돌려준다** — 목록의 `loadMorePosts` 와 같은 이유다. 데이터를 주면
 * 클라이언트가 항목을 그려야 하고, 그러면 카드 컴포넌트와 포맷터가 전부
 * 클라이언트 번들로 들어간다.
 *
 * **`excludeIds` 로 중복을 거른다.** 이어받는 사이 새 글이 쌓이면 커서가
 * 밀려 같은 글이 다시 온다(Dart 검색 화면도 `seen` 집합으로 같은 처리를
 * 한다 — 목록 쪽에는 없는 처리다).
 *
 * 실패하면 null 이다. 첫 검색이면 호출부가 안내 문구를 보이고, 더 받기면
 * 조용히 버튼만 되살린다.
 */
export async function searchAction(
  q: string,
  cursor?: number,
  excludeIds: number[] = [],
): Promise<SearchPage | null> {
  const query = q.trim();
  // 서버가 400 을 주는 길이는 아예 부르지 않는다.
  if (query.length < SEARCH_MIN_LENGTH) return null;

  const token = await readAuthToken();

  // 검색 결과는 입력마다 달라 공유 캐시에 담을 이점이 없다.
  const result = await searchPosts(
    { q: query, cursor },
    token === null ? { cache: 'no-store' } : { token, cache: 'no-store' },
  );

  if (!result.ok) return null;

  const seen = new Set(excludeIds);
  const posts = result.value.posts.filter((p) => !seen.has(p.id));

  return {
    items: posts.map((post) => <PostCard key={post.id} post={post} />),
    ids: posts.map((p) => p.id),
    nextCursor: result.value.nextCursor,
  };
}
