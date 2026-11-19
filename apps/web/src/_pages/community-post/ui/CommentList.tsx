import type { Comment } from 'warding-api';

import { timeAgo } from '@/shared/lib';

/**
 * 댓글 목록 — Flutter `features/community/presentation/widgets/comment_tile.dart`
 * 의 웹 구현.
 *
 * **답글은 1단까지만 접는다.** `parentId` 는 항상 최상위 댓글을 가리키므로
 * (답글의 답글도 같은 층) 트리를 재귀로 그리지 않는다. 최상위 하나와 그에
 * 딸린 답글들을 평평하게 늘어놓고, 누구에게 한 말인지는 `@닉네임` 이 알린다.
 *
 * **지워진 댓글도 행을 남긴다.** 서버가 `status` 를 VISIBLE 이 아닌 값으로
 * 주면서 `body`·`author` 를 null 로 비운다 — 답글이 달린 댓글이 통째로
 * 사라지면 대화가 끊겨 읽을 수 없게 되기 때문이다.
 *
 * 서버가 **오래된 순**으로 준다. 대화가 위에서 아래로 읽히도록 그 순서를
 * 그대로 쓴다.
 */
export function CommentList({ comments }: { comments: Comment[] }) {
  if (comments.length === 0) {
    return <p className="comments__empty">첫 댓글을 남겨보세요</p>;
  }

  // 최상위 → 그 답글 순으로 늘어놓는다. 서버 순서(오래된 순)를 각 묶음
  // 안에서도 유지한다.
  const replies = new Map<number, Comment[]>();
  for (const c of comments) {
    if (c.parentId === null) continue;
    const bucket = replies.get(c.parentId);
    if (bucket === undefined) replies.set(c.parentId, [c]);
    else bucket.push(c);
  }

  const roots = comments.filter((c) => c.parentId === null);

  return (
    <ul className="comments">
      {roots.map((root) => (
        <li key={root.id}>
          <CommentRow comment={root} />
          {(replies.get(root.id) ?? []).map((reply) => (
            <CommentRow key={reply.id} comment={reply} isReply />
          ))}
        </li>
      ))}
    </ul>
  );
}

function CommentRow({ comment, isReply = false }: { comment: Comment; isReply?: boolean }) {
  const hidden = comment.status !== 'VISIBLE';

  return (
    <div className={isReply ? 'comment comment--reply' : 'comment'}>
      {hidden ? (
        <p className="comment__hidden">{hiddenLabel(comment.status)}</p>
      ) : (
        <>
          <div className="comment__head">
            <span className="comment__author">
              {/* 닉네임을 따로 감싼다 — `text-overflow: ellipsis` 는 블록
                  컨테이너의 인라인 콘텐츠에만 걸려서, flex 부모의 텍스트
                  노드에 직접 주면 잘리기만 하고 말줄임표가 안 나온다. */}
              <span className="comment__nickname">
                {comment.author?.nickname ?? '탈퇴한 사용자'}
              </span>
              {comment.author?.teamImageUrl ? (
                <img
                  className="comment__team"
                  src={comment.author.teamImageUrl}
                  alt=""
                  loading="lazy"
                />
              ) : null}
            </span>
            <span className="comment__time">
              {timeAgo(comment.createdAt)}
              {comment.edited ? ' · 수정됨' : ''}
            </span>
          </div>

          <p className="comment__body">
            {/* 답글이 누구에게 향하는지. 본문 앞에 붙는다(Dart 와 같다). */}
            {comment.mentionNickname === null ? null : (
              <span className="comment__mention">@{comment.mentionNickname} </span>
            )}
            {comment.body}
          </p>

          {/* 추천은 0 이면 그리지 않는다 — 목록 카드와 같은 판단이다. */}
          {comment.likeCount > 0 ? (
            <span className="comment__like">추천 {comment.likeCount}</span>
          ) : null}
        </>
      )}
    </div>
  );
}

/** 지워진 사유별 문구. 사유를 숨기면 왜 비었는지 알 수 없다. */
function hiddenLabel(status: Comment['status']): string {
  switch (status) {
    case 'DELETED':
      return '삭제된 댓글입니다';
    case 'BLOCKED':
      return '차단한 사용자의 댓글입니다';
    case 'HIDDEN':
      return '숨겨진 댓글입니다';
    default:
      return '';
  }
}
