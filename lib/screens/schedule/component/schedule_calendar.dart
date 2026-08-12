import 'package:flutter/material.dart';

import '../../../model/calendar_week_start.dart';
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
    this.onDateTap,
    this.weekStart = CalendarWeekStart.monday,
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

  /// 경기가 있는 날짜 칸을 탭하면 그 날짜로 호출한다. null 이면 탭 비활성.
  final ValueChanged<DateTime>? onDateTap;

  /// 캘린더 시작 요일 설정. 요일 헤더·월간 그리드에 그대로 전달한다.
  final CalendarWeekStart weekStart;

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  /// 지금까지 겪은 월 전환 횟수. 매 전환마다 하나씩 늘려 [CalendarMonthGrid]의
  /// key로 쓴다.
  ///
  /// 예전엔 그리드 key를 `ValueKey(month)`로, 즉 달 값 그 자체로 줬다.
  /// 그러면 왕복으로 빠르게 스와이프할 때(예: 8월→9월→8월) 아직 빠져나가는
  /// 중인 '옛 8월' 그리드와 새로 들어오는 '새 8월' 그리드가 같은 key를
  /// 갖게 되고, AnimatedSwitcher가 둘을 같은 자식으로 오인해 위치가 튀었다
  /// (스와이프 시 날짜가 밀리는 버그). 전환마다 고유하게 증가하는 값을
  /// key로 쓰면 같은 달로 왕복해도 절대 겹치지 않는다.
  int _generation = 0;

  /// 세대(generation)별 슬라이드 시작 위치(beginX). +1: 오른쪽에서 들어와
  /// 왼쪽으로 나감(다음 달), -1: 그 반대(이전 달). 전환이 시작되는 순간
  /// 관련된 두 세대(새로 들어오는 쪽·빠지는 쪽)에 각각 고정해 두면 이후
  /// 다른 전환이 일어나도 영향받지 않는다.
  final Map<int, double> _beginXByGeneration = {0: 1};

  /// 드래그 중 누적된 가로 이동량. 빠른 플릭이 아니라 천천히 끝까지 미는
  /// 드래그도 인식하려면 속도뿐 아니라 이동 거리도 봐야 한다.
  double _dragDx = 0;

  @override
  void didUpdateWidget(ScheduleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 월 변경 방향에 맞춰 슬라이드 방향을 정한다 (스와이프·날짜피커 공통).
    if (widget.month != oldWidget.month) {
      final forward = widget.month.isAfter(oldWidget.month);
      final previousGeneration = _generation;
      _generation++;
      _beginXByGeneration[_generation] = forward ? 1 : -1;
      _beginXByGeneration[previousGeneration] = forward ? -1 : 1;
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
          CalendarWeekdayHeader(scale: scale, weekStart: widget.weekStart),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              // 그리드가 화면보다 짧을 때 기본 center 정렬이면 요일 헤더와
              // 사이가 떠 보인다. 위(top)에 붙도록 정렬을 바꾼다.
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                // 이 자식(세대)이 화면에 들어올 때 고정된 시작 위치를 그대로
                // 쓴다 — 그 사이 다른 전환이 일어나도 바뀌지 않는다.
                final key = child.key;
                final generation = key is ValueKey<int> ? key.value : _generation;
                final beginX = _beginXByGeneration[generation] ?? 1;
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
                key: ValueKey(_generation),
                month: month,
                scale: scale,
                weekStart: widget.weekStart,
                selectedDate: widget.selectedDate,
                onDateTap: widget.onDateTap,
                matchesOf:
                    (date) =>
                        date.month == month.month
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
    // 빠른 플릭은 속도(primaryVelocity, logical px/s)로, 천천히 끝까지 미는
    // 드래그는 누적 이동 거리(_dragDx)로 판단한다. 둘 중 하나만 기준을
    // 넘어도 넘긴다 — 속도만 보면 느리지만 화면 절반 넘게 민 드래그를
    // 놓쳐서 "잘 안 넘어간다"는 느낌을 준다.
    const velocityThreshold = 200.0;
    final distanceThreshold = 60 * scale;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -velocityThreshold ||
            (velocity <= 0 && _dragDx < -distanceThreshold)) {
          onShift(1);
        } else if (velocity > velocityThreshold ||
            (velocity >= 0 && _dragDx > distanceThreshold)) {
          onShift(-1);
        }
      },
      child: calendar,
    );
  }
}
