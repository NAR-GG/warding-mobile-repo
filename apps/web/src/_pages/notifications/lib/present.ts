import {
  type MemberNotification,
  type NotificationType,
  championName,
  gameDurationSeconds,
  isCommunityType,
  isSoloRankEnd,
  kda,
  playerName,
  queueType,
  soloRankWin,
} from 'warding-api';

/**
 * 알림 한 건 → 화면에 그릴 값.
 *
 * Flutter 는 `buildNotificationFeedCard` 가 종류별로 **다른 위젯**을
 * 고르는데(솔랭 시작·종료·공용), 셋 다 `NotificationCard` 를 쓰고 문구만
 * 다르다. 그래서 웹은 **문구를 여기서 정하고 카드는 하나**로 둔다.
 *
 * **솔랭 문구를 서버 title/body 대신 다시 조립한다** — Dart 와 같은 이유다.
 * 서버 문구가 한국어 고정이라 로케일을 못 맞춘다.
 */
export type NotificationView = {
  /** 아이콘 경로. `public/icons/` 아래다. */
  icon: string;
  /** 아이콘을 줄여 그릴지 — 커뮤니티 아이콘이 캔버스를 꽉 채워 커 보인다. */
  iconSize: number;
  title: string;
  body: string;
  /** `2026-11-23 16:06` */
  absolute: string;
  /** `1시간 전` */
  relative: string;
};

/** 종류별 아이콘. Dart `notificationIconFor` 와 같은 표다. */
function iconFor(type: NotificationType): string {
  switch (type) {
    case 'setStart':
      return '/icons/play.svg';
    case 'setEnd':
      return '/icons/closing.svg';
    case 'liveEvent':
      return '/icons/pause.svg';
    case 'communityLike':
      // 좋아요는 빈 하트 — 꽉 찬 하트는 응원팀 배너와 겹친다.
      return '/icons/empty-heart.svg';
    case 'communityComment':
    case 'communityReply':
      return '/icons/message-circle-heart.svg';
    default:
      return '/icons/bell.svg';
  }
}

/**
 * 아이콘 표시 크기(375 기준).
 *
 * 기본 44 인데 커뮤니티 아이콘만 줄인다 — 24 뷰박스를 꽉 채우는 그림이라
 * 44 로 키우면 헤드셋(여백 포함)보다 훨씬 커 보인다. 빈 하트는 가장자리까지
 * 채워서 한 단계 더 낮춘다. 세 숫자 모두 Dart 와 같다.
 */
function iconSizeFor(type: NotificationType): number {
  if (type === 'communityLike') return 22;
  if (isCommunityType(type)) return 26;
  return 44;
}

/** `2026-11-23 16:06` — Dart `formatNotificationAbsolute` 와 같다. */
export function formatAbsolute(t: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return (
    `${t.getFullYear()}-${p(t.getMonth() + 1)}-${p(t.getDate())} ` +
    `${p(t.getHours())}:${p(t.getMinutes())}`
  );
}

/**
 * `방금 전` · `N분 전` · `N시간 전` · `N일 전`.
 *
 * Dart `formatNotificationRelative` 와 같은 경계다. `shared/lib/timeAgo` 를
 * 안 쓰는 이유는 그쪽이 커뮤니티 글 기준이라 경계가 다를 수 있어서다 —
 * 같은 화면에서 두 규칙이 섞이면 안 된다.
 */
export function formatRelative(t: Date, now: Date): string {
  const min = Math.floor((now.getTime() - t.getTime()) / 60000);
  if (min < 1) return '방금 전';
  if (min < 60) return `${min}분 전`;
  const hours = Math.floor(min / 60);
  if (hours < 24) return `${hours}시간 전`;
  return `${Math.floor(hours / 24)}일 전`;
}

/**
 * 받침에 따라 `로` / `으로` — Flutter `core/util/korean_particle.dart` 의
 * `particleEuro` 와 같은 판정이다.
 *
 * 받침이 없거나 ㄹ 받침이면 `로`, 나머지는 `으로`. 한글이 아니면 `으로`.
 * **하드코딩하면 "아칼리으로"·"자야로" 가 섞인다.**
 */
export function particleEuro(word: string): string {
  if (word === '') return '으로';
  const last = word.codePointAt(word.length - 1) ?? 0;
  if (last < 0xac00 || last > 0xd7a3) return '으로';
  const jongseong = (last - 0xac00) % 28;
  return jongseong === 0 || jongseong === 8 ? '로' : '으로';
}

export function toView(n: MemberNotification, now: Date): NotificationView {
  const base = {
    icon: iconFor(n.type),
    iconSize: iconSizeFor(n.type),
    absolute: formatAbsolute(n.createdAt),
    relative: formatRelative(n.createdAt, now),
  };

  if (n.type === 'playerSoloRank') {
    const champ = championName(n);
    // 솔랭은 아이콘이 헤드셋이다(종류 표가 bell 을 주지만, Dart 의
    // Rank*Notification 이 headset 으로 덮어쓴다).
    const icon = '/icons/headset.svg';

    if (isSoloRankEnd(n)) {
      const win = soloRankWin(n);
      const k = kda(n);
      // **승패로만 가른다.** match-v5 결과를 못 읽은 종료 알림은 win 이
      // null 이고, 그때는 '{챔피언} 경기 종료' 로만 쓴다(Dart 와 같다).
      let body: string;
      if (win === null) {
        body = `${champ} 경기 종료`;
      } else {
        body = `${champ}${particleEuro(champ)} ${win ? '승리' : '패배'}`;
        if (k !== null && k !== '') body += ` · ${k}`;
        // **1분 미만은 생략한다** — '0분' 은 정보가 아니라 오해를 만든다.
        const minutes = Math.floor((gameDurationSeconds(n) ?? 0) / 60);
        if (minutes >= 1) body += ` · ${minutes}분`;
      }
      return {
        ...base,
        icon,
        title: `${playerName(n)} 선수가 솔랭을 끝냈어요`,
        body,
      };
    }

    return {
      ...base,
      icon,
      title: `${playerName(n)} 선수가 솔랭을 시작했어요`,
      body: `${champ}${particleEuro(champ)} ${queueType(n)} 플레이 중`,
    };
  }

  // 팀 이벤트·커뮤니티 — 서버 title/body 를 그대로 쓴다.
  return { ...base, title: n.title, body: n.body };
}
