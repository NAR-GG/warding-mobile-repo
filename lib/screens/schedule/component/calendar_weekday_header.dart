import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../model/calendar_week_start.dart';
import '../../../styles/app_colors.dart';

/// 요일 헤더 — 월·화·수·목·금·토·일.
///
/// 요일 한 칸당 위 14 / 아래 10 패딩을 주고, 행 아래에 1px 그라데이션
/// 구분선([AppColors.narBg])을 둔다.
class CalendarWeekdayHeader extends StatelessWidget {
  const CalendarWeekdayHeader({
    super.key,
    required this.scale,
    this.weekStart = CalendarWeekStart.monday,
  });

  final double scale;
  final CalendarWeekStart weekStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final weekdays = weekStart.orderedWeekdayLabels([
      l.weekdayMon, l.weekdayTue, l.weekdayWed, l.weekdayThu,
      l.weekdayFri, l.weekdaySat, l.weekdaySun,
    ]);
    return Column(
      children: [
        Row(
          children: [
            for (final day in weekdays)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 14 * scale, bottom: 10 * scale),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600, // SF Pro 590 ≈ Semibold
                      fontSize: 16 * scale,
                      height: 1.0, // line-height 100%
                      letterSpacing: 0,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // 주간 구분선 — 1px 그라데이션
        Container(
          height: 1,
          decoration: const BoxDecoration(gradient: AppColors.narBg),
        ),
      ],
    );
  }
}
