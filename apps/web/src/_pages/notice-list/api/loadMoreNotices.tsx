'use server';

import type { ReactNode } from 'react';
import { fetchNotices } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

import { NoticeCard } from '../ui/NoticeCard';

/**
 * 다음 페이지를 받아 **그려진 항목과 다음 페이지 번호**를 돌려준다.
 *
 * 커뮤니티(`loadMorePosts`)와 같은 구조지만 **커서가 아니라 페이지 번호**다 —
 * `GET /api/notices?page&size` 가 그렇게 생겼고, Dart `NoticeViewModel` 도
 * `_page` 를 1씩 올린다. 마지막 판단도 같은 `last` 플래그를 쓴다.
 *
 * JSX 를 돌려주는 이유와 실패를 조용히 끝내는 이유는 `loadMorePosts` 의
 * 주석과 같다.
 */
export async function loadMoreNotices(
  page: number,
): Promise<{ items: ReactNode; nextPage: number | null } | null> {
  const token = await readAuthToken();

  const result = await fetchNotices(
    { page },
    token === null ? { revalidate: 60 } : { token, cache: 'no-store' },
  );

  if (!result.ok) return null;

  const { notices, last } = result.value;

  return {
    items: notices.map((notice) => <NoticeCard key={notice.id} notice={notice} />),
    nextPage: last ? null : page + 1,
  };
}
