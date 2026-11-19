import type { PostSummary } from 'warding-api';

import { timeAgo } from '@/shared/lib';

/**
 * 글 한 줄 — Flutter `features/community/presentation/widgets/
 * post_list_item.dart` 의 웹 구현.
 *
 * **목록과 검색이 같은 카드를 쓴다.** 서버가 두 응답을 같은 모양으로 주므로
 * (실측 2026-11-19: 필드 14개 동일) Dart 쪽도 `PostListItem` 하나를 재사용한다.
 * FSD 에서 page 끼리는 서로 import 할 수 없어 아래 레이어인 `shared` 에 둔다.
 *
 * **`packages/ui` 가 아닌 이유**는 따로다. 거기는 `core/ui/` 의 짝인데 이
 * 카드의 Dart 원본은 기능 폴더 안(`features/community/.../widgets/`)이다 —
 * 한 기능 전용 위젯을 앱 공용 자리에 두지 않는 규칙과 같다.
 *
 * 수치는 Dart 와 맞춘다 — 제목 16/w700, 미리보기 14/w400 2줄, 메타 12.5,
 * 썸네일 62, 패딩 20/18.
 *
 * 링크는 `<a>` 다. 목록 → 상세가 둘 다 웹이라 네이티브 브리지를 거칠 이유가
 * 없고, `<a>` 면 서버 컴포넌트로 남아 클라이언트 번들이 늘지 않는다
 * (`onClick` 을 서버 컴포넌트에서 넘기면 런타임에 터진다).
 */
export function PostCard({ post }: { post: PostSummary }) {
  const thumb = post.thumbnailUrl;

  return (
    <li className="post-item">
      <a className="post-item__link" href={`/community/post/${post.id}`}>
        <div className="post-item__main">
          <h2 className="post-item__title">
            {/* 투표 글은 제목 앞에 배지 — 목록을 훑을 때 바로 걸린다.
                썸네일 칸은 사진·영상용으로 남긴다. */}
            {post.hasPoll ? <span className="post-item__poll">투표</span> : null}
            {post.title}
          </h2>

          <p className="post-item__preview">{post.bodyPreview}</p>

          <div className="post-item__meta">
            {/* 추천·댓글은 0 이면 그리지 않는다. 아무도 반응하지 않은 글에
                '0' 을 붙여두면 그 사실만 강조된다(Dart 와 같은 판단). */}
            {post.likeCount > 0 ? (
              <span className="post-item__stat post-item__stat--like">
                <ThumbUpIcon />
                {post.likeCount}
              </span>
            ) : null}
            {post.commentCount > 0 ? (
              <span className="post-item__stat post-item__stat--comment">
                <CommentIcon />
                {post.commentCount}
              </span>
            ) : null}

            <span className="post-item__time">{timeAgo(post.createdAt)}</span>

            <span className="post-item__author">
              {post.author?.nickname ?? '탈퇴한 사용자'}
              {post.author?.teamImageUrl ? (
                <img
                  className="post-item__team"
                  src={post.author.teamImageUrl}
                  alt=""
                  loading="lazy"
                />
              ) : null}
            </span>
          </div>
        </div>

        {thumb !== null && thumb !== '' ? (
          <img className="post-item__thumb" src={thumb} alt="" loading="lazy" />
        ) : null}
      </a>
    </li>
  );
}

/* 아이콘은 인라인이다. Flutter 는 svg 에셋을 쓰지만(`assets/icons/*.svg`), 목록은
 * 한 화면에 수십 개가 깔려서 에셋 요청이 그만큼 늘어난다. */

function ThumbUpIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M7 22h11a2 2 0 0 0 2-1.6l1.3-7A2 2 0 0 0 19.3 11H14l.8-4a2 2 0 0 0-2-2.4l-.4 1.2L8.5 11M7 22H4a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1h3m0 11V11"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function CommentIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.9 8.9 0 0 1-3.9-.9L3 21l1.9-5.1A8.4 8.4 0 0 1 12 3.1a8.4 8.4 0 0 1 9 8.4Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
