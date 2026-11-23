'use client';

import { useRef, useState, useTransition } from 'react';
import { type MemberNotification, postId } from 'warding-api';

import { pushWebDepth } from '@/shared/bridge';
import { NotificationCard } from './NotificationCard';

import { markRead, removeNotification } from '../api/actions';

/** 삭제로 판정하는 좌스와이프 거리(px). 이보다 짧으면 되돌아간다. */
const DISMISS_PX = 96;

/**
 * 알림 한 줄 — 탭하면 글 상세로, 좌스와이프하면 삭제.
 *
 * **네이티브 `Dismissible` 의 웹 구현이다.** 포인터 이벤트로 가로 드래그를
 * 따라가고, 기준을 넘기면 지운다. 되돌리기(undo)는 없다 — 의도적 동작이라
 * 즉시 삭제하는 것이 네이티브와 같다.
 *
 * **세로 스크롤을 막지 않는다.** 가로 이동이 세로보다 확실히 클 때만
 * 드래그로 보고, 그 전까지는 브라우저 스크롤에 맡긴다 — 안 그러면 목록을
 * 세로로 넘길 때마다 카드가 흔들린다.
 */
export function NotificationRow({
  notification,
  now,
}: {
  notification: MemberNotification;
  now: Date;
}) {
  const [dx, setDx] = useState(0);
  const [gone, setGone] = useState(false);
  const [failed, setFailed] = useState(false);
  const [, start] = useTransition();

  // 제스처 상태는 리렌더를 유발할 이유가 없어 ref 에 둔다.
  const g = useRef({ x: 0, y: 0, dragging: false, decided: false });

  const target = postId(notification);

  function onPointerDown(e: React.PointerEvent) {
    // 마우스 우클릭·보조 버튼은 무시한다.
    if (e.button !== 0) return;
    g.current = { x: e.clientX, y: e.clientY, dragging: true, decided: false };
  }

  function onPointerMove(e: React.PointerEvent) {
    if (!g.current.dragging) return;
    const mx = e.clientX - g.current.x;
    const my = e.clientY - g.current.y;

    if (!g.current.decided) {
      // 아직 방향을 못 정했다. 세로가 크면 스크롤로 넘긴다.
      if (Math.abs(my) > Math.abs(mx) && Math.abs(my) > 8) {
        g.current.dragging = false;
        return;
      }
      if (Math.abs(mx) < 8) return;
      g.current.decided = true;
      e.currentTarget.setPointerCapture(e.pointerId);
    }

    // 왼쪽으로만 민다(endToStart) — 오른쪽은 0 에서 멈춘다.
    setDx(Math.min(0, mx));
  }

  function onPointerUp() {
    if (!g.current.dragging) return;
    g.current.dragging = false;

    if (dx <= -DISMISS_PX) {
      setGone(true);
      start(async () => {
        const ok = await removeNotification(notification.id);
        if (!ok) {
          // 되살린다 — 네이티브도 실패 시 항목을 복구하고 문구를 띄운다.
          setGone(false);
          setFailed(true);
        }
      });
      return;
    }
    setDx(0);
  }

  function open() {
    // 드래그 직후의 클릭은 무시한다.
    if (dx !== 0) return;
    start(() => markRead(notification.id));
    if (target === null) return;
    pushWebDepth();
    window.location.assign(`/community/post/${target}`);
  }

  if (gone) return null;

  return (
    <li className="noti-row">
      {/* 좌스와이프에서 드러나는 빨간 삭제 배경 — 네이티브와 같은 모양. */}
      <span className="noti-row__delete" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" className="noti-row__trash">
          <path
            d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        삭제
      </span>

      <div
        className="noti-row__slide"
        style={{ transform: `translateX(${dx}px)` }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      >
        <button
          type="button"
          className="noti-row__hit"
          onClick={open}
          // 원글이 없는 알림(공지·제재 등)은 이동할 곳이 없다.
          disabled={target === null}
        >
          <NotificationCard notification={notification} now={now} />
        </button>
      </div>

      {failed ? (
        <p className="noti-row__error" role="alert">
          삭제에 실패했어요
        </p>
      ) : null}
    </li>
  );
}
