import { NotificationsHeader } from './NotificationsHeader';

/** 알림을 받는 동안 보이는 화면. */
export function NotificationsSkeleton() {
  return (
    <>
      <NotificationsHeader unreadCount={0} />
      <ul className="noti-list" aria-hidden="true">
        {[0, 1, 2, 3].map((i) => (
          <li key={i} className="noti-card">
            <span className="noti-card__icon-box">
              <span className="skeleton noti-card__icon" />
            </span>
            <div className="noti-card__text">
              <div className="skeleton skeleton--line" />
              <div className="skeleton skeleton--line skeleton--short" />
            </div>
          </li>
        ))}
      </ul>
    </>
  );
}
