import 'package:flutter/material.dart';

import '../../../model/calendar_week_start.dart';
import 'calendar_day_cell.dart';
import 'calendar_match.dart';
import 'calendar_today_badge.dart';

/// 월간 날짜 그리드.
///
/// 주(week) 시작 요일은 [weekStart]로 설정한다(기본값 월요일). 이전·다음
/// 달 날짜로 빈 칸을 채워 항상 7×[gridWeeks] 격자를 만들고, 가용 세로 공간을
/// 그 행 수로 균등 분배한다.
///
/// 한때는 그 달의 실제 주 수(4~6)로 나눴다. 주 수가 적은 달은 칸이 그만큼
/// 커져 뷰포트를 꽉 채우니 한 화면만 보면 더 나았다. 그런데 [ScheduleCalendar]
/// 의 `PageView` 는 스와이프 중 두 달을 나란히 보여 준다. 5주 달과 6주 달이
/// 붙으면 칸 높이가 달라 가로 구분선이 서로 어긋나고, 전환이 미끄러지는 게
/// 아니라 어긋난 두 격자가 지나가는 것처럼 보였다. 행 수를 고정하면 어느
/// 달이든 격자 좌표가 같아서 선이 그대로 이어진다.
///
/// 화면이 너무 작아 계산된 행 높이가 [minRowHeight] 밑으로 떨어지면
/// (콘텐츠가 눌려 안 보이는 것을 막기 위해) 그 최소값을 지키고, 그 경우에
/// 한해 세로로 스크롤된다.
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.scale,
    required this.matchesOf,
    this.selectedDate,
    this.onDateTap,
    this.weekStart = CalendarWeekStart.monday,
  });

  final DateTime month;
  final double scale;
  final CalendarWeekStart weekStart;

  /// 특정 날짜의 경기 목록을 반환한다.
  final List<CalendarMatch> Function(DateTime date) matchesOf;

  /// 강조할 선택 날짜. null 이면 강조 없음.
  final DateTime? selectedDate;

  /// 경기가 있는 날짜 칸을 탭하면 그 날짜로 호출한다. null 이면 탭 비활성.
  final ValueChanged<DateTime>? onDateTap;

  /// 날짜 숫자 + 경기 칩이 눌리지 않고 보이는 최소 행 높이(스케일 적용 전).
  /// 스켈레톤도 같은 값을 써야 로딩 전후로 칸 높이가 바뀌지 않는다.
  static const double minRowHeight = 64.0;

  /// 그리드 행 수. 어느 달이든 이 수로 고정한다 — 한 달이 걸칠 수 있는
  /// 최대 주 수라 이 달 날짜가 잘리는 경우는 없다. 스켈레톤도 같은 값을 쓴다.
  static const int gridWeeks = 6;

  /// [availableHeight] 를 [weekCount] 주로 나눈 행 높이. 너무 좁아 [minRowHeight]
  /// 밑으로 떨어지면 최소값을 지킨다(그 경우 그리드가 뷰포트를 넘어 스크롤된다).
  ///
  /// 스켈레톤과 실제 그리드가 같은 높이를 쓰도록 계산을 여기 모아 둔다.
  static double rowHeightFor({
    required double availableHeight,
    required int weekCount,
    required double scale,
  }) {
    final floor = minRowHeight * scale;
    if (!availableHeight.isFinite) return floor;
    final fit = availableHeight / weekCount;
    return fit > floor ? fit : floor;
  }

  @override
  Widget build(BuildContext context) {
    // 그리드 시작일이 속한 주에서, 설정된 시작 요일까지 거슬러 올라갈 일수.
    final leadingDays = weekStart.leadingDays(month);
    // 달마다 다르지 않게 고정한다 — 이유는 클래스 주석 참고.
    const weekCount = gridWeeks;
    final today = DateTime.now();

    // today 가 그리드에서 몇 번째 주에 있는지 (그리드 밖이면 -1).
    final gridStart = DateTime(month.year, month.month, 1 - leadingDays);
    final todayOffset = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(gridStart).inDays;
    final todayWeek = (todayOffset >= 0 && todayOffset < weekCount * 7)
        ? todayOffset ~/ 7
        : -1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        // 가용 세로 공간을 고정 행 수로 균등 분배 → 어느 달이든 같은 좌표.
        final rowHeight = rowHeightFor(
          availableHeight: availableHeight,
          weekCount: weekCount,
          scale: scale,
        );
        final totalHeight = rowHeight * weekCount;
        final needsScroll = totalHeight > availableHeight;
        final cellWidth = constraints.maxWidth / 7;

        final grid = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var week = 0; week < weekCount; week++)
              SizedBox(
                height: rowHeight,
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
                          final dayMatches = matchesOf(date);
                          return Expanded(
                            child: CalendarDayCell(
                              date: date,
                              matches: dayMatches,
                              // 경기가 있는 날만 탭 가능(다른 달·빈 날은 matchesOf 가 [] 라 비활성).
                              onTap:
                                  (onDateTap != null && dayMatches.isNotEmpty)
                                  ? () => onDateTap!(date)
                                  : null,
                              // 마지막 열 오른쪽엔 세로 테두리 없음.
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

        if (todayWeek < 0) {
          return needsScroll ? SingleChildScrollView(child: grid) : grid;
        }

        final todayDow = todayOffset % 7; // 오늘 칸의 열 (월=0 … 일=6)
        final stack = SizedBox(
          height: totalHeight,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              grid,
              Positioned(
                // 오늘 칸 왼쪽 세로선에서 배지 폭(30)만큼 왼쪽, 윗 선 위로
                // 24만큼 띄운다. 단 그리드 첫 주(top)·첫 열(left)이면 음수가
                // 되어 잘리므로 0 으로 막아 항상 보이게 한다.
                left: (todayDow * cellWidth - 30 * scale).clamp(
                  0.0,
                  double.infinity,
                ),
                top: (todayWeek * rowHeight - 24 * scale).clamp(
                  0.0,
                  double.infinity,
                ),
                child: CalendarTodayBadge(scale: scale),
              ),
            ],
          ),
        );

        // 배지 오른쪽 끝이 오늘 칸의 왼쪽 세로선에 닿게, 윗 선에 걸치도록 띄운다.
        return needsScroll ? SingleChildScrollView(child: stack) : stack;
      },
    );
  }
}
