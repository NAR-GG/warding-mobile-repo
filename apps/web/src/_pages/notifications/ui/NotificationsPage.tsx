import { fetchNotifications } from 'warding-api/server';

import { readAuthToken } from '@/shared/auth/index.server';

import { NotificationRow } from './NotificationRow';
import { NotificationsHeader } from './NotificationsHeader';

/**
 * 커뮤니티 알림함 — 열한 번째 웹뷰 전환 화면.
 *
 * **진입점이 커뮤니티 헤더의 벨 하나다.** 그 벨은 이미 웹이고 지금은
 * `navigate('notification')` 으로 네이티브를 부르는데, 이 화면이 웹으로
 * 오면 **그 브리지 호출이 `<Link>` 로 바뀐다** — 브리지가 하나 줄어든다.
 *
 * **커뮤니티 알림만 다룬다**(`group=COMMUNITY`). 경기 알림은 마이구독
 * 피드가 담당해서 네이티브의 [전체]·[경기] 탭이 없다.
 *
 * **로그인 필수다**(실측 2026-11-23, 무인증 401). 캐시하지 않는다 —
 * 읽음 상태가 바로 바뀐다.
 */
export async function NotificationsPage() {
  const token = await readAuthToken();

  if (token === null) {
    return (
      <>
        <NotificationsHeader unreadCount={0} />
        <p className="activity-empty">로그인이 필요합니다</p>
      </>
    );
  }

  const result = await fetchNotifications(
    { group: 'COMMUNITY' },
    { token, cache: 'no-store' },
  );

  if (!result.ok) {
    const { kind } = result.failure;
    const message =
      kind === 'unauthorized'
        ? '로그인이 필요합니다'
        : kind === 'network'
          ? '연결이 불안정합니다. 잠시 후 다시 시도해 주세요.'
          : '알림을 불러오지 못했어요.';
    return (
      <>
        <NotificationsHeader unreadCount={0} />
        <p className="activity-empty">{message}</p>
      </>
    );
  }

  const { notifications, unreadCount } = result.value;
  // 상대 시각 기준을 **한 번만** 정한다 — 항목마다 now 를 만들면 같은
  // 렌더 안에서 기준이 흔들린다.
  const now = new Date();

  return (
    <>
      <NotificationsHeader unreadCount={unreadCount} />

      {notifications.length === 0 ? (
        <p className="noti-empty">알림이 없어요</p>
      ) : (
        <ul className="noti-list">
          {notifications.map((n) => (
            <NotificationRow key={n.id} notification={n} now={now} />
          ))}
        </ul>
      )}
    </>
  );
}
