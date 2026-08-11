import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import 'calendar_weekday_header.dart';

/// 캘린더 최초 로딩 중 표시할 스켈레톤.
/// [ScheduleCalendar] 와 동일한 뼈대(요일 헤더 + 5주 그리드, 칸 92*scale)에
/// 회색 박스를 깔고 opacity 를 펄스시킨다. [MatchCardSkeleton] 과 동일한 톤.
/// 요일 헤더는 로딩과 무관한 고정 라벨이라 실제 위젯을 그대로 재사용한다.
class ScheduleCalendarSkeleton extends StatefulWidget {
  const ScheduleCalendarSkeleton({super.key, this.scale = 1});

  final double scale;

  @override
  State<ScheduleCalendarSkeleton> createState() =>
      _ScheduleCalendarSkeletonState();
}

class _ScheduleCalendarSkeletonState extends State<ScheduleCalendarSkeleton>
    with SingleTickerProviderStateMixin {
  /// 로딩 중엔 실제 달의 주 수를 몰라 통상적인 달 길이로 채운다.
  static const int _weekCount = 5;

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
    final rowHeight = 92.0 * scale;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekdayHeader(scale: scale),
          Expanded(
            child: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final opacity = 0.3 + (_ctrl.value * 0.3); // 0.3 ↔ 0.6 펄스
                  Widget box({double? w, required double h, double r = 2}) =>
                      Opacity(
                        opacity: opacity,
                        child: Container(
                          width: w,
                          height: h,
                          decoration: BoxDecoration(
                            color: AppColors.narLine2,
                            borderRadius: BorderRadius.circular(r),
                          ),
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
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var week = 0; week < _weekCount; week++)
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
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
