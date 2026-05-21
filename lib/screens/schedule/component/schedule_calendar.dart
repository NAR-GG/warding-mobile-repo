import 'package:flutter/material.dart';

import 'calendar_match.dart';
import 'calendar_month_grid.dart';
import 'calendar_weekday_header.dart';

// CalendarMatch 를 함께 노출 — 이 파일만 import 해도 타입을 쓸 수 있다.
export 'calendar_match.dart';

/// 월간 경기 캘린더.
///
/// 요일 헤더([CalendarWeekdayHeader])와 월간 그리드([CalendarMonthGrid])로
/// 구성된다. 월이 바뀌면 그리드가 좌우로 슬라이드 전환되고, 좌우 스와이프로
/// 월을 넘길 수 있다([onMonthShift]).
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
    super.key,
    required this.month,
    required this.matchesByDay,
    this.onMonthShift,
    this.selectedDate,
  });

  /// 표시할 월 (1일 0시로 정규화된 DateTime).
  final DateTime month;

  /// 일(day) → 그 날의 경기 목록.
  final Map<int, List<CalendarMatch>> matchesByDay;

  /// 좌우 스와이프로 월을 넘길 때 호출. 인자는 이동량(-1: 이전, +1: 다음).
  /// null 이면 스와이프가 비활성된다.
  final ValueChanged<int>? onMonthShift;

  /// 날짜 피커에서 고른 날짜. 그 칸 배경을 강조한다. null 이면 강조 없음.
  final DateTime? selectedDate;

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  /// 슬라이드 방향 — +1: 다음 달(왼쪽으로 밀림), -1: 이전 달(오른쪽으로).
  double _direction = 1;

  @override
  void didUpdateWidget(ScheduleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 월 변경 방향에 맞춰 슬라이드 방향을 정한다 (스와이프·날짜피커 공통).
    if (widget.month != oldWidget.month) {
      _direction = widget.month.isAfter(oldWidget.month) ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    final month = widget.month;
    final matchesByDay = widget.matchesByDay;

    final calendar = Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekdayHeader(scale: scale),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (child, animation) {
                // 들어오는 그리드는 _direction 쪽에서, 나가는 그리드는
                // 그 반대쪽으로 슬라이드한다.
                final key = child.key;
                final incoming =
                    key is ValueKey<DateTime> && key.value == month;
                final beginX = incoming ? _direction : -_direction;
                return ClipRect(
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(beginX, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: CalendarMonthGrid(
                key: ValueKey(month),
                month: month,
                scale: scale,
                selectedDate: widget.selectedDate,
                matchesOf: (date) => date.month == month.month
                    ? (matchesByDay[date.day] ?? const [])
                    : const [],
              ),
            ),
          ),
        ],
      ),
    );

    final onShift = widget.onMonthShift;
    if (onShift == null) return calendar;

    // 좌우 스와이프로 월 이동 — 왼쪽으로 밀면 다음 달, 오른쪽이면 이전 달.
    // primaryVelocity 단위는 logical px/s. 의도치 않은 미세 드래그는 무시.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -200) {
          onShift(1);
        } else if (velocity > 200) {
          onShift(-1);
        }
      },
      child: calendar,
    );
  }
}
