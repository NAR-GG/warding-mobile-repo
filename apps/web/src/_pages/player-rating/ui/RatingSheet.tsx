'use client';

import { useState, useTransition } from 'react';
import { Button, CommonButton, ConfirmDialog } from 'warding-ui';

import { requestNavigate } from '@/shared/bridge';

import { deleteRating, saveRating } from '../api/saveRating';
import { StarInput } from './StarInput';

/** 한줄평 최대 길이. Dart `RatingCommentSheet._maxLength` 와 같다. */
const MAX_LENGTH = 150;

/**
 * 평점·한줄평 작성 — Flutter `rating_comment_sheet.dart` 의 웹 구현.
 *
 * **네이티브 바텀시트 대신 `<dialog>` 다.** 포커스 가둠·ESC·바깥 클릭을
 * 브라우저가 처리하고, 키보드가 올라올 때 시트를 밀어 올리는 것도
 * `env(keyboard-inset-height)` 없이 뷰포트가 알아서 한다.
 *
 * **비로그인이면 네이티브 로그인 화면을 연다** — 웹에 로그인 화면이 없다
 * (카카오·네이버 SDK 가 네이티브에 있다). 그래서 이 한 건만 브리지를 쓴다.
 */
export function RatingSheet({
  gameId,
  participantId,
  playerName,
  position,
  signedIn,
  rateable,
  myRating,
}: {
  gameId: string;
  participantId: number;
  playerName: string;
  position: string;
  signedIn: boolean;
  rateable: boolean;
  myRating: { rating: number; comment: string | null } | null;
}) {
  const [open, setOpen] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [rating, setRating] = useState(myRating?.rating ?? 0);
  const [comment, setComment] = useState(myRating?.comment ?? '');
  const [failed, setFailed] = useState<string | null>(null);
  const [pending, start] = useTransition();

  // 세트가 끝나기 전에는 작성할 수 없다. 버튼을 숨기지 않고 비활성으로
  // 두는 것은 Dart 와 같다 — 자리가 사라지면 레이아웃이 흔들린다.
  if (!rateable) {
    return (
      <p className="rating-sheet__closed">아직 평가할 수 없는 경기예요</p>
    );
  }

  function openSheet() {
    if (!signedIn) {
      // 네이티브가 로그인 화면을 띄운다. 돌아오면 쿠키가 새로 심기고
      // 이 화면이 다시 로드된다.
      requestNavigate('login');
      return;
    }
    setFailed(null);
    setRating(myRating?.rating ?? 0);
    setComment(myRating?.comment ?? '');
    setOpen(true);
  }

  function submit() {
    if (rating <= 0) {
      setFailed('별점을 선택해 주세요');
      return;
    }
    start(async () => {
      const ok = await saveRating(gameId, participantId, rating, comment);
      if (ok) setOpen(false);
      else setFailed('평점 저장에 실패했어요');
    });
  }

  function remove() {
    start(async () => {
      const ok = await deleteRating(gameId, participantId);
      setConfirmDelete(false);
      if (!ok) setFailed('삭제에 실패했어요');
    });
  }

  return (
    <>
      {/* 네이티브는 `NarButtonVariant.set1`(narDark300 회색, 전체 폭)이다 —
          그라데이션 버튼이 아니다. 양옆 10 도 Dart 와 같다. */}
      <div className="rating-sheet__actions">
        <Button variant="set1" onClick={openSheet}>
          {myRating ? '평점 수정하기' : '평점 남기기'}
        </Button>
        {myRating ? (
          <button
            type="button"
            className="wd-cbtn wd-cbtn--compact wd-cbtn--text"
            onClick={() => setConfirmDelete(true)}
          >
            평점 삭제
          </button>
        ) : null}
      </div>

      {failed !== null && !open ? (
        <p className="rating-sheet__error" role="alert">
          {failed}
        </p>
      ) : null}

      <dialog
        className="rating-sheet"
        open={open}
        aria-label="평점 남기기"
      >
        <div className="rating-sheet__card">
          <p className="rating-sheet__player">
            {playerName}
            {position ? <span className="rating-sheet__pos">{position}</span> : null}
          </p>

          <StarInput value={rating} onChange={setRating} />

          <textarea
            className="rating-sheet__input"
            value={comment}
            maxLength={MAX_LENGTH}
            placeholder="한줄평을 남겨 주세요"
            onChange={(e) => setComment(e.target.value)}
          />
          <p className="rating-sheet__counter">
            {comment.length}
            <span>/{MAX_LENGTH}</span>
          </p>

          {failed !== null ? (
            <p className="rating-sheet__error" role="alert">
              {failed}
            </p>
          ) : null}

          <div className="rating-sheet__buttons">
            <button
              type="button"
              className="wd-cbtn wd-cbtn--compact wd-cbtn--text"
              onClick={() => setOpen(false)}
              disabled={pending}
            >
              취소
            </button>
            <CommonButton
              variant="primary"
              onClick={submit}
              disabled={pending}
            >
              등록
            </CommonButton>
          </div>
        </div>
      </dialog>

      <ConfirmDialog
        open={confirmDelete}
        title="내 평점을 삭제하시겠습니까?"
        message="삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다."
        confirmLabel="삭제"
        pending={pending}
        onCancel={() => setConfirmDelete(false)}
        onConfirm={remove}
      />
    </>
  );
}
