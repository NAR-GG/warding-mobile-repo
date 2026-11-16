// 경기 종료 알림 카드 — **아직 피드에 연결되지 않았다.**
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

import 'package:warding/core/ui/notification_card.dart';
import 'package:warding/core/theme/app_colors.dart';

/// 경기 종료 알림. monitor-x(closing) 아이콘 + 경기 정보 + 평점 남기기 링크.
class MatchEndNotification extends StatelessWidget {
  const MatchEndNotification({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.season,
    required this.dateTime,
    required this.relativeTime,
    this.onRatingTap,
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

  /// '경기 평점 남기기' 링크 탭 콜백.
  final VoidCallback? onRatingTap;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return NotificationCard(
      icon: 'assets/icons/closing.svg',
      title: l.matchEndNotificationTitle(teamA, teamB),
      body: l.matchEndNotificationBody(season, teamA, teamB),
      action: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRatingTap,
        child: _GradientLink(text: l.leaveMatchRating, scale: scale),
      ),
      dateTime: dateTime,
      relativeTime: relativeTime,
      scale: scale,
    );
  }
}

/// 그라데이션 밑줄 텍스트 링크.
class _GradientLink extends StatelessWidget {
  const _GradientLink({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.narBg.createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
          fontSize: 14 * scale,
          height: 1.45,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.narText, // ShaderMask 가 그라데이션으로 덮음
          color: AppColors.narText,
        ),
      ),
    );
  }
}
