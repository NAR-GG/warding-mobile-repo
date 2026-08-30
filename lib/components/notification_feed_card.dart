import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../model/member_notification.dart';
import '../screens/subscription/component/rank_end_notification.dart';
import '../screens/subscription/component/rank_start_notification.dart';
import 'notification_card.dart';

/// 알림 한 건 → 카드 위젯. 마이구독 피드와 알림함이 같은 카드를 그리도록
/// 여기로 뺐다(커뮤니티 후속 문서 A절 — "카드를 그대로 재사용").
/// 탭·스와이프 동작은 화면마다 달라 화면이 감싼다.
Widget buildNotificationFeedCard(
  MemberNotification n,
  double scale,
  AppLocalizations l,
) {
  if (n.type == MemberNotificationType.playerSoloRank && n.isSoloRankEnd) {
    // 시작·종료가 같은 type 이라 data.eventType 으로만 갈린다.
    return RankEndNotification(
      playerName: n.playerName,
      champion: n.championName,
      win: n.soloRankWin,
      kda: n.kda,
      durationSeconds: n.gameDurationSeconds,
      dateTime: formatNotificationAbsolute(n.createdAt),
      relativeTime: formatNotificationRelative(n.createdAt, l),
      scale: scale,
    );
  }
  if (n.type == MemberNotificationType.playerSoloRank) {
    return RankStartNotification(
      playerName: n.playerName,
      champion: n.championName,
      queueType: n.queueType,
      dateTime: formatNotificationAbsolute(n.createdAt),
      relativeTime: formatNotificationRelative(n.createdAt, l),
      scale: scale,
    );
  }
  // 팀 이벤트·커뮤니티 — 서버 title/body 를 공용 카드로.
  return NotificationCard(
    icon: notificationIconFor(n.type),
    title: n.title,
    body: n.body,
    dateTime: formatNotificationAbsolute(n.createdAt),
    relativeTime: formatNotificationRelative(n.createdAt, l),
    scale: scale,
  );
}

String notificationIconFor(MemberNotificationType type) {
  switch (type) {
    case MemberNotificationType.setStart:
      return 'assets/icons/play.svg';
    case MemberNotificationType.setEnd:
      return 'assets/icons/closing.svg';
    case MemberNotificationType.liveEvent:
      return 'assets/icons/pause.svg';
    case MemberNotificationType.playerSoloRank:
      return 'assets/icons/bell.svg';
    case MemberNotificationType.communityComment:
    case MemberNotificationType.communityReply:
      return 'assets/icons/message-circle.svg';
    case MemberNotificationType.communityReportResult:
    case MemberNotificationType.communityRestriction:
    case MemberNotificationType.unknown:
      return 'assets/icons/bell.svg';
  }
}

String formatNotificationAbsolute(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 상대 시각 ('방금 전', 'N분 전', 'N시간 전', 'N일 전').
String formatNotificationRelative(DateTime t, AppLocalizations l) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inMinutes < 60) return l.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.hoursAgo(diff.inHours);
  return l.daysAgo(diff.inDays);
}
