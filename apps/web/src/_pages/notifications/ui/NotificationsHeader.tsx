'use client';

import { useTransition } from 'react';
import { DetailHeader } from 'warding-ui';

import { goBack } from '@/shared/bridge';

import { markAllRead } from '../api/actions';

/**
 * 알림함 헤더 — 우측에 '모두 읽음'.
 *
 * **안 읽은 알림이 없으면 흐리게 둔다**(누를 수는 있다) — Dart 가 색만
 * 바꾸고 비활성화하지는 않는 것과 같다.
 */
export function NotificationsHeader({ unreadCount }: { unreadCount: number }) {
  const [pending, start] = useTransition();

  return (
    <DetailHeader
      title="커뮤니티 알림"
      onBack={goBack}
      trailing={
        <button
          type="button"
          className={`noti-readall${unreadCount > 0 ? '' : ' noti-readall--idle'}`}
          onClick={() => start(() => void markAllRead())}
          disabled={pending}
        >
          모두 읽음
        </button>
      }
    />
  );
}
