import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/notification_card.dart';

/// 경기 시작 알림. monitor-play 아이콘 + 응원 팀 경기 시작 안내.
class MatchStartNotification extends StatelessWidget {
  const MatchStartNotification({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.season,
    required this.dateTime,
    required this.relativeTime,
    this.scale = 1,
  });

  /// 홈 팀명 (예: 'T1').
  final String teamA;

  /// 원정 팀명 (예: 'GEN').
  final String teamB;

  /// 시즌 표기 (예: 'LCK 2026 시즌').
  final String season;

  final String dateTime;
  final String relativeTime;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NotificationCard(
      icon: 'assets/icons/play.svg',
      title: l.matchStartNotificationTitle(teamA, teamB),
      body: l.matchStartNotificationBody(season, teamA, teamB),
      dateTime: dateTime,
      relativeTime: relativeTime,
      scale: scale,
    );
  }
}
