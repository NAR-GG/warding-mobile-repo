import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import 'calendar_match.dart';
import 'calendar_match_chip_stack.dart';

/// 날짜 한 칸. 왼쪽 상단에 날짜 숫자, 그 아래 경기 칩 세로 스택,
/// 칸 위·아래·오른쪽에 0.5px 구분선(바깥 가장자리·마지막 열 제외).
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.matches,
    required this.showRightBorder,
    required this.showTopBorder,
    required this.isToday,
    required this.isSelected,
    required this.scale,
    this.onTap,
    this.isLoading = false,
  });

  final DateTime date;
  final List<CalendarMatch> matches;
  final bool showRightBorder;
  final bool showTopBorder;
  final bool isToday;

  /// 이 칸의 경기 데이터가 아직 조회 중인지. true 면 칩 자리에 펄스
  /// 스켈레톤을 보여준다 — [matches] 가 비어 있어도 실제로 없는 것과
  /// 아직 모르는 것을 구분해야 한다.
  final bool isLoading;

  /// 날짜 피커에서 고른 날짜인지. true 면 칸 배경을 강조한다.
  final bool isSelected;
  final double scale;

  /// 칸을 탭했을 때 콜백. null 이면 탭 비활성(경기 없는 날·다른 달 칸 등).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.narText4, width: 0.5);
    final cell = Container(
      decoration: BoxDecoration(
        // 선택 칸은 narDark500 단색, 아니면 오늘 칸만 그라데이션.
        color: isSelected ? AppColors.narDark500 : null,
        gradient: !isSelected && isToday ? AppColors.narTodayBg : null,
        border: Border(
          top: showTopBorder ? side : BorderSide.none,
          bottom: side,
          right: showRightBorder ? side : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 날짜 숫자 — 좌상단
          Padding(
            padding: EdgeInsets.only(
              left: 4 * scale,
              top: 3 * scale,
              bottom: 3 * scale,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600, // SF Pro 590 ≈ Semibold
                  fontSize: 14 * scale,
                  height: 1.0, // line-height 100%
                  letterSpacing: 0,
                  color: isToday ? AppColors.narTextRed : AppColors.narText4,
                ),
              ),
            ),
          ),
          // 경기 칩 세로 스택 — 남은 높이 안에서, 넘치면 dots.
          Expanded(
            child: CalendarMatchChipStack(
              matches: matches,
              scale: scale,
              isLoading: isLoading,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: cell,
    );
  }
}
