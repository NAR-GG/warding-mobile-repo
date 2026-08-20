import 'package:flutter/material.dart';

import '../../../model/calendar_week_start.dart';
import '../../../styles/app_colors.dart';
import 'calendar_month_grid.dart';
import 'calendar_weekday_header.dart';

/// 캘린더 최초 로딩 중 표시할 스켈레톤.
///
/// [CalendarMonthGrid] 와 동일한 뼈대(요일 헤더 + 월간 그리드)에 회색 박스를
/// 깔고 opacity 를 펄스시킨다. [MatchCardSkeleton] 과 동일한 톤. 요일 헤더는
/// 로딩과 무관한 고정 라벨이라 실제 위젯을 그대로 재사용한다.
///
/// 로딩 중이라 없는 것은 '그 달의 경기 목록'뿐이고 달력 자체는 이미 알 수
/// 있으므로, 주 수와 행 높이를 실제 그리드와 같은 규칙으로 계산한다 —
/// 조회가 끝나는 순간 줄 수나 칸 높이가 바뀌어 화면이 튀지 않는다.
class ScheduleCalendarSkeleton extends StatefulWidget {
  const ScheduleCalendarSkeleton({
    super.key,
    required this.month,
    this.scale = 1,
    this.weekStart = CalendarWeekStart.monday,
  });

  /// 로딩 중인 달 (1일 0시로 정규화된 DateTime).
  final DateTime month;

  final double scale;

  /// 캘린더 시작 요일 설정. 요일 헤더·주 수 계산에 그대로 쓴다.
  final CalendarWeekStart weekStart;

  @override
  State<ScheduleCalendarSkeleton> createState() =>
      _ScheduleCalendarSkeletonState();
}

class _ScheduleCalendarSkeletonState extends State<ScheduleCalendarSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    const side = BorderSide(color: AppColors.narText4, width: 0.5);
    // 실제 그리드와 같은 계산 — 로딩이 끝나도 줄 수·칸 높이가 그대로다.
    final weekCount = widget.weekStart.weekCount(widget.month);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekdayHeader(scale: scale, weekStart: widget.weekStart),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rowHeight = CalendarMonthGrid.rowHeightFor(
                  availableHeight: constraints.maxHeight,
                  weekCount: weekCount,
                  scale: scale,
                );
                // 뷰포트보다 커지는 건 화면이 너무 짧아 최소 높이를 지킬
                // 때뿐이다. 그때만 스크롤한다 — 실제 그리드와 같은 규칙.
                final needsScroll =
                    rowHeight * weekCount > constraints.maxHeight;
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final opacity = 0.3 + (_ctrl.value * 0.3); // 0.3 ↔ 0.6 펄스
                    // 펄스는 Opacity 위젯 대신 색의 알파로 낸다. 캘린더는
                    // 날짜 칸이 한 화면에 서른 개 넘게 깔려서, 박스마다
                    // 오프스크린 레이어를 뜨면 그 비용이 칸 수만큼 곱해진다.
                    Widget box({double? w, required double h, double r = 2}) =>
                        Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            color: AppColors.narLine2.withValues(
                              alpha: opacity,
                            ),
                            borderRadius: BorderRadius.circular(r),
                          ),
                        );
                    Widget dayCell({
                      required bool showRightBorder,
                      required bool showTopBorder,
                    }) => Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: showTopBorder ? side : BorderSide.none,
                          bottom: side,
                          right: showRightBorder ? side : BorderSide.none,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 4 * scale,
                          top: 3 * scale,
                          bottom: 3 * scale,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            box(w: 14 * scale, h: 14 * scale), // 날짜 숫자
                            SizedBox(height: 6 * scale),
                            box(w: 28 * scale, h: 8 * scale), // 경기 칩
                          ],
                        ),
                      ),
                    );
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
                                  Expanded(
                                    child: dayCell(
                                      showRightBorder: dow != 6,
                                      showTopBorder: week == 0,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                    return needsScroll
                        ? SingleChildScrollView(child: grid)
                        : grid;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
