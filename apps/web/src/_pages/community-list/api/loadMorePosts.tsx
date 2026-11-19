'use server';

import type { ReactNode } from 'react';
import { fetchPosts } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';
import { PostCard } from '@/shared/ui';

/**
 * 다음 페이지를 받아 **그려진 항목과 다음 커서**를 돌려준다.
 *
 * **JSX 를 돌려주는 이유** — 항목 렌더링을 서버에 남기기 위해서다. 데이터를
 * 돌려주면 클라이언트가 `PostCard` 를 그려야 하고, 그러면 그 컴포넌트와
 * 거기 딸린 포맷터까지 전부 클라이언트 번들로 들어간다. 첫 페이지를 SSR 로
 * 그려 얻은 이득을 두 번째 페이지부터 반납하는 셈이다.
 *
 * **실패하면 조용히 끝낸다**(`posts: null`). Dart `loadMore` 와 같은 판단이다 —
 * 이미 보고 있는 목록이 그대로 남아 있는데 에러 화면으로 덮을 이유가 없다.
 * 호출부는 버튼을 되살려 다시 누를 수 있게만 하면 된다.
 */
export async function loadMorePosts(
  cursor: number,
): Promise<{ items: ReactNode; nextCursor: number | null } | null> {
  const token = await readAuthToken();

  const result = await fetchPosts(
    { cursor },
    token === null ? { revalidate: 15 } : { token, cache: 'no-store' },
  );

  if (!result.ok) return null;

  const { posts, nextCursor } = result.value;

  return {
    items: posts.map((post) => <PostCard key={post.id} post={post} />),
    nextCursor,
  };
}
