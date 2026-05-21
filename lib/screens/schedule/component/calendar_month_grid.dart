import 'package:flutter/material.dart';

import 'calendar_day_cell.dart';
import 'calendar_match.dart';
import 'calendar_today_badge.dart';

/// 월간 날짜 그리드.
///
/// 주(week)는 월요일 시작. 이전·다음 달 날짜로 빈 칸을 채워 7×N 격자를
/// 만들고, 각 주 행을 [Expanded] 로 균등 분할해 스크롤 없이 남은 높이를
/// 모두 채운다.
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.scale,
    required this.matchesOf,
    this.selectedDate,
  });

  final DateTime month;
  final double scale;

  /// 특정 날짜의 경기 목록을 반환한다.
  final List<CalendarMatch> Function(DateTime date) matchesOf;

  /// 강조할 선택 날짜. null 이면 강조 없음.
  final DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    // 그리드 시작일이 속한 주의 월요일까지 거슬러 올라갈 일수.
    final leadingDays = month.weekday - DateTime.monday; // 월요일이면 0
    // 이번 달 일수 (다음 달 0일 = 이번 달 말일).
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 앞쪽 빈 칸 + 이번 달 일수를 7로 올림 → 필요한 주 수.
    final weekCount = ((leadingDays + daysInMonth) / 7).ceil();
    final today = DateTime.now();

    // today 가 그리드에서 몇 번째 주에 있는지 (그리드 밖이면 -1).
    final gridStart = DateTime(month.year, month.month, 1 - leadingDays);
    final todayOffset = DateTime(today.year, today.month, today.day)
        .difference(gridStart)
        .inDays;
    final todayWeek = (todayOffset >= 0 && todayOffset < weekCount * 7)
        ? todayOffset ~/ 7
        : -1;

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var week = 0; week < weekCount; week++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var dow = 0; dow < 7; dow++)
                  Builder(
                    builder: (context) {
                      // DateTime 생성자가 음수·초과 일수를 알아서 정규화한다.
                      final date = DateTime(
                        month.year,
                        month.month,
                        1 - leadingDays + week * 7 + dow,
                      );
                      return Expanded(
                        child: CalendarDayCell(
                          date: date,
                          matches: matchesOf(date),
                          // 마지막 열(일요일) 오른쪽엔 세로 테두리 없음.
                          showRightBorder: dow != 6,
                          // 첫 주만 위쪽 테두리. 이후 행은 윗 행의 아래
                          // 테두리가 위 선 역할을 한다.
                          showTopBorder: week == 0,
                          isToday:
                              date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day,
                          isSelected:
                              selectedDate != null &&
                              date.year == selectedDate!.year &&
                              date.month == selectedDate!.month &&
                              date.day == selectedDate!.day,
                          scale: scale,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );

    if (todayWeek < 0) return grid;

    // 배지 오른쪽 끝이 오늘 칸의 왼쪽 세로선에 닿게, 윗 선에 걸치도록 띄운다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final rowHeight = constraints.maxHeight / weekCount;
        final todayDow = todayOffset % 7; // 오늘 칸의 열 (월=0 … 일=6)
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            grid,
            Positioned(
              // 오늘 칸 왼쪽 세로선에서 배지 폭(30)만큼 왼쪽으로.
              left: todayDow * cellWidth - 30 * scale,
              top: todayWeek * rowHeight - 24 * scale,
              child: CalendarTodayBadge(scale: scale),
            ),
          ],
        );
      },
    );
  }
}
