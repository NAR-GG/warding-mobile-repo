import { notFound } from 'next/navigation';
import { fetchMyComments, fetchMyPosts, fetchScraps } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

import { TAB_EMPTY, isMyActivityTab, type MyActivityTab } from '../model/tabs';
import { LoadMoreActivity } from './LoadMoreActivity';
import { MyActivityHeader } from './MyActivityHeader';
import { normalizeActivity } from './normalizeActivity';

/**
 * 마이페이지 "내 활동" — 내가 쓴 글 · 내가 쓴 댓글 · 스크랩.
 *
 * **셋 다 로그인 필수다.** 커뮤니티 목록·공지와 달리 토큰 없이는 서버가
 * 401 을 준다. 네이티브가 쿠키를 심고 나서 로드하므로 정상 경로에서는
 * 토큰이 늘 있지만, 만료된 채 들어올 수 있어 안내를 그린다.
 *
 * **캐시하지 않는다.** 사용자마다 다른 목록이라 공유 캐시에 담으면 남의
 * 활동이 보인다(커뮤니티 상세의 `viewer` 와 같은 이유).
 *
 * **탭 하나만 받는다.** 라우트로 갈랐으니 보지 않는 탭까지 부를 이유가
 * 없다 — 네이티브는 한 화면이라 탭을 누를 때 받아 왔다.
 */
export async function MyActivityPage({
  params,
}: {
  params: Promise<{ tab: string }>;
}) {
  const { tab: raw } = await params;
  // 모르는 탭은 404 다 — 빈 목록으로 보여 주면 사용자가 "내 글이 없다" 로
  // 읽는다.
  if (!isMyActivityTab(raw)) notFound();
  const tab: MyActivityTab = raw;

  const token = await readAuthToken();

  if (token === null) {
    return (
      <main>
        <MyActivityHeader />
        <p className="activity-empty">로그인이 필요합니다</p>
      </main>
    );
  }

  const options = { token, cache: 'no-store' as const };

  const result = await (tab === 'posts'
    ? fetchMyPosts({}, options)
    : tab === 'comments'
      ? fetchMyComments({}, options)
      : fetchScraps({}, options));

  if (!result.ok) {
    const { kind } = result.failure;
    // Dart 는 실패 종류를 가리지 않고 같은 문구를 쓴다. 다만 만료 토큰으로
    // 들어오는 경우가 실제로 있어 그것만 구분해 준다.
    const message =
      kind === 'unauthorized'
        ? '로그인이 필요합니다'
        : kind === 'network'
          ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
          : '글을 불러오지 못했어요.';
    return (
      <main>
        <MyActivityHeader />
        <p className="activity-empty">{message}</p>
      </main>
    );
  }

  const { items, nextCursor } = normalizeActivity(result.value);

  return (
    <main>
      <MyActivityHeader />

      {items.length === 0 ? (
        <p className="activity-empty">{TAB_EMPTY[tab]}</p>
      ) : (
        <ul className="post-list">
          {items}
          {nextCursor === null ? null : (
            <LoadMoreActivity tab={tab} cursor={nextCursor} />
          )}
        </ul>
      )}
    </main>
  );
}
