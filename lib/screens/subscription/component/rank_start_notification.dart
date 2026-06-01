import 'package:flutter/material.dart';

import '../../../components/notification_card.dart';

/// 선수 랭크 시작 감지 알림. headset 아이콘 + 선수/챔피언 정보.
class RankStartNotification extends StatelessWidget {
  const RankStartNotification({
    super.key,
    required this.playerName,
    required this.champion,
    required this.dateTime,
    required this.relativeTime,
    this.scale = 1,
  });

  /// 선수명 (예: 'Faker').
  final String playerName;

  /// 챔피언명 (예: '아지르').
  final String champion;

  final String dateTime;
  final String relativeTime;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return NotificationCard(
      icon: 'assets/icons/headset.svg',
      title: '$playerName 선수 랭크 시작 감지!',
      body: '지금 $playerName 선수가 $champion으로 솔로 랭크를 시작했습니다',
      dateTime: dateTime,
      relativeTime: relativeTime,
      scale: scale,
    );
  }
}
