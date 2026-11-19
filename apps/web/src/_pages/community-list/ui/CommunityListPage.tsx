import { fetchPosts } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

import { PostListItem } from './PostListItem';

/**
 * 커뮤니티 글 목록.
 *
 * **웹이 가져가는 건 목록 본문뿐이다.** 하단 탭·알림 벨·검색·글쓰기 FAB 는 앱
 * 셸이라 네이티브에 남는다 — 웹뷰가 탭을 그리면 네이티브 탭과 두 겹이 된다.
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
  const result = await fetchPosts(
    {},
    token === null ? { revalidate: 15 } : { token, cache: 'no-store' },
  );

  if (!result.ok) {
    const { kind } = result.failure;
    const message =
      kind === 'network'
        ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
        : '글 목록을 불러오지 못했습니다.';
    return <main className="post-error">{message}</main>;
  }

  const { posts } = result.value;

  if (posts.length === 0) {
    return <main className="post-error">아직 글이 없습니다.</main>;
  }

  return (
    <main>
      <ul className="post-list">
        {posts.map((post) => (
          <PostListItem key={post.id} post={post} />
        ))}
      </ul>
    </main>
  );
}
