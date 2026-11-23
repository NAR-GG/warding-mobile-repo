/**
 * 알림 도메인 타입.
 *
 * Flutter `features/notification/domain/member_notification.dart` 의 널
 * 판단을 복제한다.
 */

/** 알림 종류. 백엔드 enum 과 1:1 이다. */
export type NotificationType =
  | 'setStart'
  | 'setEnd'
  | 'liveEvent'
  | 'playerSoloRank'
  | 'communityComment'
  | 'communityReply'
  | 'communityLike'
  | 'communityReportResult'
  | 'communityRestriction'
  | 'unknown';

/** 알림함 '커뮤니티' 로 분류되는 타입인지. Dart `isCommunity` 와 같다. */
export function isCommunityType(type: NotificationType): boolean {
  return (
    type === 'communityComment' ||
    type === 'communityReply' ||
    type === 'communityLike' ||
    type === 'communityReportResult' ||
    type === 'communityRestriction'
  );
}

/**
 * 알림 한 건.
 *
 * **`data` 는 문자열 맵이다.** 서버가 종류마다 다른 키를 싣고(선수명·챔피언·
 * KDA…), Dart 도 `Map<String, String>` 으로 받아 getter 로 꺼낸다. 타입을
 * 종류별로 가르면 서버가 키를 하나 추가할 때마다 양쪽을 고쳐야 한다.
 */
export type MemberNotification = {
  id: number;
  type: NotificationType;
  title: string;
  body: string;
  data: Record<string, string>;
  read: boolean;
  createdAt: Date;
};

/** 알림 목록 한 페이지. */
export type NotificationPage = {
  notifications: MemberNotification[];
  /** 필터와 무관한 전체 기준 미읽음 수. */
  unreadCount: number;
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
};

// ── `data` 에서 값을 꺼내는 함수들 ───────────────────────────
//
// Dart 의 getter 와 짝이다. 키 이름을 화면이 직접 알지 않게 한다.

/** 솔랭 종료 알림인가. 시작·종료가 같은 type 이라 `eventType` 으로 가른다. */
export const isSoloRankEnd = (n: MemberNotification): boolean =>
  n.data.eventType === 'END';

export const playerName = (n: MemberNotification): string =>
  n.data.playerName ?? '선수';

export const championName = (n: MemberNotification): string =>
  n.data.championName ?? '챔피언 정보를 불러오는 중';

export const queueType = (n: MemberNotification): string =>
  n.data.queueType ?? '솔로 랭크';

/** 승패. 종료 알림이라도 결과를 못 읽었으면 키가 없어 null 이다. */
export function soloRankWin(n: MemberNotification): boolean | null {
  if (n.data.win === 'true') return true;
  if (n.data.win === 'false') return false;
  return null;
}

export const kda = (n: MemberNotification): string | null => n.data.kda ?? null;

/** 경기 길이(초). 진행 중이거나 타임스탬프가 이상하면 서버가 키를 뺀다. */
export function gameDurationSeconds(n: MemberNotification): number | null {
  const v = Number.parseInt(n.data.gameDurationSeconds ?? '', 10);
  return Number.isFinite(v) ? v : null;
}

/** 커뮤니티 알림의 원글 id — 탭하면 글 상세로 간다. */
export function postId(n: MemberNotification): number | null {
  const v = Number.parseInt(n.data.postId ?? '', 10);
  return Number.isFinite(v) ? v : null;
}
