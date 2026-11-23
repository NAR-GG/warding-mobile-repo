import {
  API_BASE_URL,
  deleteJson,
  getJson,
  postVoid,
  type RequestOptions,
  type Result,
} from '../client';
import { toNotificationPage } from './mappers';
import type { NotificationPage } from './types';

/**
 * 받은 알림 목록.
 *
 * `GET /api/mobile/me/notifications` — Flutter `ApiConfig.notificationsUrl`
 * 과 같다. **인증 필수다**(실측 2026-11-23, 무인증 401).
 *
 * `group='COMMUNITY'` 면 커뮤니티 알림만 오고 `unreadCount` 도 그 범위다 —
 * 알림함이 쓰는 형태고, 마이구독 피드는 group 없이 전체를 받는다.
 *
 * **캐시하지 않는다.** 사용자마다 다르고 읽음 상태가 바로 바뀐다.
 */
export function fetchNotifications(
  {
    group,
    type,
    page = 0,
    size = 20,
  }: { group?: string; type?: string; page?: number; size?: number } = {},
  options: RequestOptions = {},
): Promise<Result<NotificationPage>> {
  const q = new URLSearchParams({ page: String(page), size: String(size) });
  if (type !== undefined) q.set('type', type);
  if (group !== undefined) q.set('group', group);
  return getJson(
    `${API_BASE_URL}/mobile/me/notifications?${q}`,
    toNotificationPage,
    options,
  );
}

/** 전체 읽음 처리. `group` 이 있으면 그 묶음만. */
export function markAllNotificationsRead(
  { group }: { group?: string } = {},
  options: RequestOptions = {},
): Promise<Result<void>> {
  const suffix = group === undefined ? '' : `?group=${encodeURIComponent(group)}`;
  return postVoid(
    `${API_BASE_URL}/mobile/me/notifications/read${suffix}`,
    options,
  );
}

/** 단건 읽음 처리. */
export function markNotificationRead(
  id: number,
  options: RequestOptions = {},
): Promise<Result<void>> {
  return postVoid(
    `${API_BASE_URL}/mobile/me/notifications/${id}/read`,
    options,
  );
}

/** 단건 삭제. */
export function deleteNotification(
  id: number,
  options: RequestOptions = {},
): Promise<Result<void>> {
  return deleteJson(`${API_BASE_URL}/mobile/me/notifications/${id}`, options);
}
