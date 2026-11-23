'use client';

import { useEffect, useRef } from 'react';

import { Button } from './Button';

/**
 * 확인 알럿 — Flutter `core/ui/nar_alert_dialog.dart` 의 웹 구현.
 *
 * 수치는 Dart 와 맞춘다 — 카드 285 · radius 16 · padding 24,
 * 타이틀 18/w500, 설명 12/w500, 버튼은 취소 `type2` / 확인 `type1`.
 *
 * **`<dialog>` 를 쓴다.** 직접 만든 오버레이는 포커스 가둠·ESC·바깥 클릭을
 * 전부 손으로 구현해야 하는데, 브라우저가 `showModal()` 로 이미 한다.
 * 웹뷰(WKWebView)도 지원한다.
 */
export type ConfirmDialogProps = {
  open: boolean;
  title: string;
  message: string;
  cancelLabel?: string;
  confirmLabel?: string;
  onCancel: () => void;
  onConfirm: () => void;
  /** 확인 버튼을 눌러 처리 중인 동안 비활성화한다. */
  pending?: boolean;
};

export function ConfirmDialog({
  open,
  title,
  message,
  cancelLabel = '취소',
  confirmLabel = '확인',
  onCancel,
  onConfirm,
  pending = false,
}: ConfirmDialogProps) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (el === null) return;
    // 이미 열린 dialog 에 showModal 을 다시 부르면 예외가 난다.
    if (open && !el.open) el.showModal();
    if (!open && el.open) el.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      className="wd-dialog"
      // ESC·바깥 클릭으로 닫힐 때도 상태를 되돌린다 — 안 하면 `open` 이
      // true 로 남아 다시 열리지 않는다.
      onClose={onCancel}
      onCancel={(e) => {
        // 처리 중에는 ESC 로 못 닫게 한다(요청은 이미 나갔다).
        if (pending) e.preventDefault();
      }}
    >
      <div className="wd-dialog__card">
        <h2 className="wd-dialog__title">{title}</h2>
        <p className="wd-dialog__message">{message}</p>
        <div className="wd-dialog__actions">
          <Button variant="type2" onClick={onCancel} disabled={pending}>
            {cancelLabel}
          </Button>
          <Button variant="type1" onClick={onConfirm} disabled={pending}>
            {confirmLabel}
          </Button>
        </div>
      </div>
    </dialog>
  );
}
