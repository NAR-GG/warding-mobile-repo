'use client';

import { requestNavigate } from '@/shared/bridge';

/**
 * 알림 벨 — Flutter `community_screen.dart` 헤더의 벨.
 *
 * **배지는 웹이 그리고 화면은 네이티브가 연다.** 알림함(`NotificationScreen`)
 * 이 아직 네이티브라 탭하면 브리지로 넘긴다 — 그 화면이 웹으로 오면 이
 * 컴포넌트는 `WebLink` 로 바뀐다.
 *
 * **푸시가 와도 즉시 갱신되지 않는다.** 네이티브는 `feedRefreshTick` 으로
 * 바로 다시 세지만, 웹은 목록의 `revalidate: 15` 를 따라간다. 배지가 최대
 * 15초 늦는 것은 받아들인 값이다 — 그보다 자주 세려고 브리지를 늘리면
 * 앱 업데이트에 또 묶인다.
 */
export function NotificationBell({ unreadCount }: { unreadCount: number }) {
  return (
    <button
      type="button"
      className="board-header__action"
      onClick={() => requestNavigate('notification')}
      aria-label={
        unreadCount > 0 ? `알림 ${unreadCount}건 안 읽음` : '알림'
      }
    >
      <BellIcon />
      {/* 0 이면 배지를 그리지 않는다 — 네이티브와 같다. */}
      {unreadCount > 0 ? (
        <span className="board-header__badge">
          {/* 세 자리가 넘으면 숫자가 배지를 밀어낸다. */}
          {unreadCount > 99 ? '99+' : unreadCount}
        </span>
      ) : null}
    </button>
  );
}

function BellIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M13.7 21a2 2 0 0 1-3.4 0"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
