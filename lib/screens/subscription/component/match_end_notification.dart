import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/notification_card.dart';
import '../../../styles/app_colors.dart';

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
