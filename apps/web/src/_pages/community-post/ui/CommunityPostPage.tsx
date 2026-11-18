import { parseBlocks } from 'warding-api';
// 서버 호출은 `/server` 서브경로다 — 클라이언트 번들로 새지 않게 갈라 뒀다.
import { fetchPostDetail } from 'warding-api/server';
import { BoardBadge } from 'warding-ui';

import { readAuthToken } from '@/shared/auth/index.server';

import { PostBody } from './PostBody';
import { PostHeader } from './PostHeader';

/**
 * 커뮤니티 글 상세 — 첫 웹뷰 전환 화면.
 *
 * **SSR 로 본문까지 그린다.** 비회원 조회가 열려 있어(실측 2026-11-17) 토큰
 * 없이도 서버가 글을 받을 수 있다. 웹뷰가 빈 HTML 을 받고 JS 를 기다리는
 * CSR 대비 첫 페인트가 빠른 것이 전환의 목적이다.
 *
 * **토큰은 쿠키로 온다.** 네이티브가 웹뷰 쿠키스토어에 심어 주므로 첫 요청부터
 * 서버가 토큰을 들고 API 를 부른다 — 좋아요·스크랩 상태까지 SSR 로 그려져
 * 깜빡임이 없다. 브라우저로 직접 열면 토큰이 없어 비로그인 화면이 된다.
 */
export async function CommunityPostPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const postId = Number(id);

  if (!Number.isFinite(postId)) {
    return <main className="post-error">잘못된 주소입니다.</main>;
  }

  const token = await readAuthToken();

  // 글은 자주 바뀌지 않지만 조회수·댓글수가 있어 길게 캐시하지 않는다.
  // 로그인 상태에서는 캐시하지 않는다 — `viewer` 가 사용자마다 달라서
  // 공유 캐시에 담으면 남의 좋아요 상태가 보인다.
  const result = await fetchPostDetail(
    postId,
    token === null ? { revalidate: 30 } : { token, cache: 'no-store' },
  );

  if (!result.ok) {
    const { kind, statusCode } = result.failure;
    // 404 는 "없는 글" 이라 사용자가 할 수 있는 일이 다르다 — 재시도해도
    // 소용없으니 다시 시도하라고 안내하지 않는다(실측: 없는 id 는 404).
    const message =
      kind === 'noData' || statusCode === 404
        ? '삭제되었거나 없는 글입니다.'
        : kind === 'network'
          ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
          : '글을 불러오지 못했습니다.';
    return <main className="post-error">{message}</main>;
  }

  const post = result.value;
  // 본문이 블록 형식이면 블록을 그린다. 그 외(PLAIN)는 평문이다.
  const blocks = post.bodyFormat === 'BLOCKS' ? parseBlocks(post.body) : [];

  return (
    <>
      <PostHeader />

      <article className="post">
        <div className="post__meta">
          <BoardBadge
            boardTeamId={post.boardTeamId}
            boardTeamCode={post.boardTeamCode}
            allLabel="전체"
          />
          <span className="post__author">{post.author?.nickname ?? '(탈퇴한 사용자)'}</span>
        </div>

        <h1 className="post__title">{post.title}</h1>

        <div className="post__stats">
          조회 {post.viewCount} · 좋아요 {post.likeCount} · 댓글 {post.commentCount}
          {post.edited ? ' · 수정됨' : ''}
          {/* 토큰이 있을 때만 내 상태를 보여준다. 비로그인은 서버가 전부
              false 로 주므로 "안 누름" 과 구분이 안 된다. */}
          {token !== null && post.viewer.liked ? ' · 내가 좋아요함' : ''}
          {token !== null && post.viewer.scrapped ? ' · 스크랩함' : ''}
        </div>

        {blocks.length > 0 ? (
          <PostBody blocks={blocks} />
        ) : (
          <p className="post__text">{post.body}</p>
        )}
      </article>
    </>
  );
}
