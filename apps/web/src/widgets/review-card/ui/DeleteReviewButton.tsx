'use client';

import { useState, useTransition } from 'react';
import { ConfirmDialog } from 'warding-ui';

import { deleteReview } from '../api/deleteReview';

/**
 * 리뷰 삭제 — 확인 후 지운다.
 *
 * **클라이언트 경계가 버튼 하나로 좁다.** 카드 본체는 서버 컴포넌트로
 * 남는다(목록 전체가 클라이언트가 되면 SSR 이득이 사라진다).
 *
 * 실패해도 화면은 그대로 두고 문구만 띄운다 — Dart 가 스낵바를 띄우는 자리다.
 */
export function DeleteReviewButton({
  gameId,
  participantId,
}: {
  gameId: string;
  participantId: number;
}) {
  const [open, setOpen] = useState(false);
  const [failed, setFailed] = useState(false);
  const [pending, start] = useTransition();

  function confirm() {
    start(async () => {
      const ok = await deleteReview(gameId, participantId);
      setOpen(false);
      // 성공하면 목록이 다시 그려지며 이 카드가 사라진다.
      if (!ok) setFailed(true);
    });
  }

  return (
    <>
      <button
        type="button"
        className="wd-cbtn wd-cbtn--compact wd-cbtn--text review-card__delete"
        onClick={() => {
          setFailed(false);
          setOpen(true);
        }}
      >
        리뷰삭제
      </button>

      {failed ? (
        <p className="review-card__error" role="alert">
          삭제에 실패했어요
        </p>
      ) : null}

      {/* 문구는 Dart l10n 과 같은 값이다 (`deleteMyRatingConfirm`·
          `deleteMyRatingMessage`) — 같은 동작에 다른 말을 쓰지 않는다. */}
      <ConfirmDialog
        open={open}
        title="내 평점을 삭제하시겠습니까?"
        message="삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다."
        confirmLabel="삭제"
        pending={pending}
        onCancel={() => setOpen(false)}
        onConfirm={confirm}
      />
    </>
  );
}
