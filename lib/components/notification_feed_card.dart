import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/app_localizations.dart';
import '../model/member_notification.dart';
import '../styles/app_colors.dart';
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
    // 커뮤니티 아이콘(하단탭과 같은 하트 말풍선)은 24 뷰박스에 꽉 찬 그림이라
    // 카드 기본 44px 로 키우면 헤드셋(44 캔버스에 여백 포함)보다 훨씬 커 보인다.
    // 44 박스 안에 26 으로 앉혀 다른 카드와 시각 크기를 맞춘다.
    iconOverride: n.type.isCommunity
        ? SizedBox(
            width: 44 * scale,
            height: 44 * scale,
            child: Center(
              child: SvgPicture.asset(
                // 좋아요는 빈 하트(꽉 찬 하트는 응원팀 배너와 겹친다),
                // 나머지 커뮤니티(댓글·답글 등)는 말풍선 하트.
                n.type == MemberNotificationType.communityLike
                    ? 'assets/icons/empty-heart.svg'
                    : 'assets/icons/message-circle-heart.svg',
                // 빈 하트(22×20)는 캔버스를 가장자리까지 채우는 그림이라
                // 말풍선 하트(24×24, 여백 포함)와 같은 폭이면 커 보인다 —
                // 22 로 낮춰 시각 크기를 맞춘다.
                width: (n.type == MemberNotificationType.communityLike
                        ? 22
                        : 26) *
                    scale,
                height: (n.type == MemberNotificationType.communityLike
                        ? 22
                        : 26) *
                    scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narText,
                  BlendMode.srcIn,
                ),
              ),
            ),
          )
        : null,
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
    case MemberNotificationType.communityLike:
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
