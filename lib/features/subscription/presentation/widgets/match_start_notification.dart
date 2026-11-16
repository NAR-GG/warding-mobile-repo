// 경기 시작 알림 카드 — **아직 피드에 연결되지 않았다.**
//
// 서버는 이미 이 알림들을 보낸다 — `MemberNotificationType` 의 setStart·
// setEnd·liveEvent 이고 `notification_feed_card.dart` 의
// `notificationIconFor` 에 아이콘도 정의돼 있다. 다만 피드 카드의 타입 분기가
// 솔랭(RankStart·RankEnd)만 그려서 이 위젯들이 아직 안 쓰인다.
//
// **미사용이라고 지우지 않는다** — 붙이기만 하면 되는 미완성 기능이다.
// 연결할 때는 실제 알림 payload 와 필드가 맞는지 먼저 확인한다.

import 'package:flutter/material.dart';
import 'package:warding/l10n/app_localizations.dart';

import 'package:warding/features/subscription/presentation/widgets/notification_card.dart';

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
