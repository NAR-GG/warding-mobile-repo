'use server';

import type { ReactNode } from 'react';
import { fetchMyComments, fetchMyPosts, fetchScraps } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

import type { MyActivityTab } from '../model/tabs';
import { normalizeActivity } from '../ui/normalizeActivity';

/**
 * 다음 페이지를 받아 **그려진 항목과 다음 커서**를 돌려준다.
 *
 * 커뮤니티 `loadMorePosts` 와 같은 구조다 — JSX 를 돌려주는 이유(항목
 * 렌더링을 서버에 남긴다)와 실패를 조용히 끝내는 이유도 같다.
 *
 * **커서의 의미가 탭마다 다르다**(글 id / 댓글 id / scrapId). 그래서 탭을
 * 같이 받고, 호출부는 어느 쪽인지 알 필요가 없다.
 */
export async function loadMoreActivity(
  tab: MyActivityTab,
  cursor: number,
): Promise<{ items: ReactNode; nextCursor: number | null } | null> {
  const token = await readAuthToken();
  if (token === null) return null;

  const options = { token, cache: 'no-store' as const };

  const result = await (tab === 'posts'
    ? fetchMyPosts({ cursor }, options)
    : tab === 'comments'
      ? fetchMyComments({ cursor }, options)
      : fetchScraps({ cursor }, options));

  if (!result.ok) return null;

  return normalizeActivity(result.value);
}
