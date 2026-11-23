import { type Json, boolOr, date, isObject, list, numOr, strOr } from '../json';
import type {
  MemberNotification,
  NotificationPage,
  NotificationType,
} from './types';

/** 백엔드 enum → 도메인 타입. Dart `MemberNotificationType.fromApi` 와 같다. */
export function toNotificationType(raw: unknown): NotificationType {
  switch (raw) {
    case 'SET_START':
      return 'setStart';
    case 'SET_END':
      return 'setEnd';
    case 'LIVE_EVENT':
      return 'liveEvent';
    case 'PLAYER_SOLO_RANK_STARTED':
      return 'playerSoloRank';
    case 'COMMUNITY_COMMENT':
      return 'communityComment';
    case 'COMMUNITY_REPLY':
      return 'communityReply';
    case 'COMMUNITY_LIKE':
      return 'communityLike';
    case 'COMMUNITY_REPORT_RESULT':
      return 'communityReportResult';
    case 'COMMUNITY_RESTRICTION':
      return 'communityRestriction';
    default:
      // **모르는 종류를 버리지 않는다.** 서버가 새 알림을 추가했을 때
      // 목록에서 사라지는 것보다, 기본 아이콘으로라도 보이는 편이 낫다.
      return 'unknown';
  }
}

export function toMemberNotification(json: Json): MemberNotification {
  // `data` 는 값이 숫자·불린으로 와도 문자열로 눕힌다 — Dart 가
  // `v.toString()` 으로 받는 것과 같다.
  const data: Record<string, string> = {};
  if (isObject(json.data)) {
    for (const [k, v] of Object.entries(json.data)) {
      if (v !== null && v !== undefined) data[k] = String(v);
    }
  }

  return {
    id: numOr(json.id, 0),
    type: toNotificationType(json.type),
    title: strOr(json.title, ''),
    body: strOr(json.body, ''),
    data,
    read: boolOr(json.read, false),
    // 파싱이 안 되면 epoch 으로 떨어뜨린다(Dart 와 같다) — 목록이 통째로
    // 비는 것보다 시각 하나가 이상한 편이 낫다.
    createdAt: date(json.createdAt) ?? new Date(0),
  };
}

export function toNotificationPage(json: unknown): NotificationPage {
  if (!isObject(json)) throw new TypeError('NotificationPage: 객체가 아니다');
  return {
    notifications: list(json.notifications, toMemberNotification),
    unreadCount: numOr(json.unreadCount, 0),
    page: numOr(json.page, 0),
    size: numOr(json.size, 0),
    totalElements: numOr(json.totalElements, 0),
    totalPages: numOr(json.totalPages, 0),
  };
}
