import Link from 'next/link';
import type { MyComment } from 'warding-api';
import { BoardBadge } from 'warding-ui';

import { timeAgo } from '@/shared/lib';

/**
 * "내가 쓴 댓글" 한 줄 — Flutter `my_comment_row.dart` 의 웹 구현.
 *
 * [배지] 원글 제목 · 댓글 본문(2줄) · 시각·추천수. 수치는 Dart 와 맞춘다
 * (패딩 20/18, 제목 12.5 w500, 본문 14.5 w700, 메타 11 w400).
 *
 * 원글이 삭제·블라인드되면 서버가 목록에서 빼 주므로 `postId` 는 항상 유효한
 * 이동 대상이다(Dart 주석과 같은 전제). 상세가 이미 웹이라 브리지를 거치지
 * 않고 `Link` 로 간다.
 */
export function MyCommentRow({ comment }: { comment: MyComment }) {
  return (
    <li className="activity-comment">
      <Link className="activity-comment__link" href={`/community/post/${comment.postId}`}>
        <span className="activity-comment__head">
          <BoardBadge
            boardTeamId={comment.boardTeamId}
            boardTeamCode={comment.boardTeamCode}
            allLabel="전체"
          />
          {/* flex 안의 텍스트 노드에는 `ellipsis` 가 안 걸린다 — span 으로
              감싸야 한다(커뮤니티 카드에서 같은 함정을 겪었다). */}
          <span className="activity-comment__title">{comment.postTitle}</span>
        </span>

        <p className="activity-comment__body">{comment.body}</p>

        {/* Dart `myCommunityCommentMeta` 와 같은 조합이다. */}
        <p className="activity-comment__meta">
          {timeAgo(comment.createdAt)} · 추천 {comment.likeCount}
        </p>
      </Link>
    </li>
  );
}
