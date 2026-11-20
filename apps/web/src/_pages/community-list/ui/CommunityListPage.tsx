import { fetchCommunityUnreadCount, fetchPosts } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';
import { WebLink } from '@/shared/ui';
import { PostCard } from '@/widgets/post-card';

import { LoadMore } from './LoadMore';
import { NotificationBell } from './NotificationBell';

/**
 * 커뮤니티 글 목록.
 *
 * **하단 탭은 네이티브가 그린다**(`app/bridge/webview_tab_screen.dart`) —
 * 웹뷰가 탭까지 그리면 두 겹이 되고, 탭 전환이 웹 라우팅이라 다른 탭으로
 * 못 간다.
 *
 * 헤더와 검색은 웹이 그린다. **알림 벨만 네이티브에 남는다** — 커뮤니티 밖
 * 저장소를 읽고 앱 생명주기·푸시 신호에 묶여 있다.
 *
 * **게시판은 하나다**(`boardTeamId=null` 고정). 팀별 3탭은 팀원 피드백(글 리젠
 * 악순환 우려)으로 네이티브 쪽에서 보류된 상태라, 웹도 탭 없이 전체 게시판만
 * 그린다. 서버 API 는 `boardTeamId` 를 받지만 지금은 넘기지 않는다.
 *
 * **읽기는 비회원도 열려 있다**(실측 2026-11-19, HTTP 200). 그래서 목록 전체를
 * 로그인 벽으로 덮지 않는다 — 쓰기만 네이티브 쪽에서 막힌다.
 */
export async function CommunityListPage() {
  const token = await readAuthToken();

  // 목록은 상세보다 자주 바뀐다(새 글이 위로 쌓인다). 로그인 상태에서는
  // 캐시하지 않는다 — 글마다 내 상태가 섞여 들어갈 여지를 두지 않는다.
  const options =
    token === null ? { revalidate: 15 } : { token, cache: 'no-store' as const };

  // **병렬로 부른다.** 미읽음 수는 목록에 의존하지 않으므로 줄세우면 왕복이
  // 두 번 쌓인다. 비로그인이면 셀 것이 없어 아예 부르지 않는다.
  const [result, unread] = await Promise.all([
    fetchPosts({}, options),
    token === null
      ? Promise.resolve(null)
      : fetchCommunityUnreadCount({ token }),
  ]);

  // 배지는 장식이라 못 세었다고 화면을 막지 않는다.
  const unreadCount = unread !== null && unread.ok ? unread.value : 0;

  if (!result.ok) {
    const { kind } = result.failure;
    const message =
      kind === 'network'
        ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
        : '글 목록을 불러오지 못했습니다.';
    return <main className="post-error">{message}</main>;
  }

  const { posts, nextCursor } = result.value;

  if (posts.length === 0) {
    return <main className="post-error">아직 글이 없습니다.</main>;
  }

  return (
    <main>
      {/* 네이티브 커뮤니티 화면(`_Header`)과 같은 구성 — 제목 + 검색 + 알림. */}
      <header className="board-header">
        <h1 className="board-header__title">커뮤니티</h1>

        <div className="board-header__actions">
          <WebLink className="board-header__action" href="/community/search">
            <SearchIcon />
          </WebLink>

          {/* 알림함 화면은 아직 네이티브다 — 벨과 배지만 웹이 그리고 탭하면
              브리지로 넘긴다. 미읽음은 커뮤니티 묶음만 센다(경기 알림은
              마이구독이 담당). */}
          <NotificationBell unreadCount={unreadCount} />
        </div>
      </header>

      <ul className="post-list">
        {posts.map((post) => (
          <PostCard key={post.id} post={post} />
        ))}
        {/* 첫 페이지가 마지막이면 버튼 자체를 그리지 않는다. */}
        {nextCursor === null ? null : <LoadMore cursor={nextCursor} />}
      </ul>

      {/* 글쓰기 — 네이티브 FAB(`_WriteFab`)과 같은 자리다. 비로그인은
          글쓰기 화면이 로그인 안내를 띄운다. 작성 간격 잠금은 아직 없다
          (네이티브는 남은 초를 버튼에 띄운다). */}
      <WebLink className="write-fab" href="/community/write">
        <PencilIcon />
        글쓰기
      </WebLink>
    </main>
  );
}

function SearchIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="11" cy="11" r="7" stroke="currentColor" strokeWidth="2" />
      <path d="M20 20l-3.5-3.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function PencilIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
