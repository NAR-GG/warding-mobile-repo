'use client';

import { useState } from 'react';
import type { Comment } from 'warding-api';

import { useDismissKeyboard } from '@/shared/lib';

import { CommentInput } from './CommentInput';
import { CommentList } from './CommentList';

/**
 * 댓글 목록 + 입력창.
 *
 * **둘을 한 컴포넌트가 감싸는 이유는 답글 대상을 공유해야 해서다.** 목록에서
 * "답글" 을 누르면 입력창 위에 "N님에게 답글" 이 뜨고, 등록할 때 그 id 가
 * `replyToCommentId` 로 나간다.
 *
 * **목록 자체는 서버가 그린 것을 받는다**(`children` 아님, props 로 받은 배열을
 * 다시 그린다). 답글 버튼이 클라이언트 핸들러를 필요로 해서 목록도 클라이언트로
 * 내려왔다 — 서버 컴포넌트에서 `onClick` 을 넘기면 런타임에 터진다.
 */
export function CommentSection({
  postId,
  comments,
}: {
  postId: number;
  comments: Comment[];
}) {
  // 빈 곳 탭·스크롤로 키보드를 내린다(네이티브와 같은 동작).
  useDismissKeyboard();

  const [replyTo, setReplyTo] = useState<Comment | null>(null);

  return (
    <>
      <section className="comments-section">
        <CommentList comments={comments} onReply={setReplyTo} />
      </section>

      <CommentInput
        postId={postId}
        replyTo={replyTo}
        onCancelReply={() => setReplyTo(null)}
        onDone={() => setReplyTo(null)}
      />
    </>
  );
}
