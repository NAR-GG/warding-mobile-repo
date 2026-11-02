import 'package:flutter/material.dart';

import '../../../model/calendar_week_start.dart';
import 'calendar_day_cell.dart';
import 'calendar_match.dart';
import 'calendar_weekday_header.dart';

/// 주간 캘린더 — 한 주(7칸)만 보여주고 좌우 스와이프로 주를 넘긴다.
///
/// 월간([ScheduleCalendar])과 따로 둔 이유: 월간 쪽 `PageView` 는 페이지
/// 단위가 '달'이고, 정착·기준월 재배치 로직이 그 전제 위에 짜여 있다. 거기에
/// '주' 단위를 겹치면 두 축이 한 컨트롤러를 두고 다툰다.
///
/// [anchorDate] 가 속한 주를 보여준다. 목록을 스크롤해 다음 주 경기로 넘어가면
/// 부모가 그 날짜를 내려주고, 이 위젯이 **옆으로 미끄러지며** 그 주로 간다 —
/// 값만 갈아끼우면 툭 바뀌어 어느 방향으로 이동했는지 알 수 없다.
class ScheduleWeekCalendar extends StatefulWidget {
  const ScheduleWeekCalendar({
    super.key,
    required this.anchorDate,
    required this.matchesOfMonth,
    this.onWeekShift,
    this.selectedDate,
    this.onDateTap,
    this.weekStart = CalendarWeekStart.monday,
  });

  /// 보여줄 주에 속한 아무 날짜. 보통 목록이 지금 보여 주는 날짜다.
  final DateTime anchorDate;

  /// 어떤 달의 '일(day) → 그 날의 경기 목록'. 한 주가 두 달에 걸칠 수 있어
  /// 달을 받아 조회한다.
  final Map<int, List<CalendarMatch>> Function(DateTime month) matchesOfMonth;

  /// 사용자가 좌우로 쓸어 주를 넘겼을 때. 인자는 이동한 주 수(-1/+1).
  /// null 이면 스와이프가 비활성된다.
  final ValueChanged<int>? onWeekShift;

  /// 강조할 선택 날짜.
  final DateTime? selectedDate;

  /// 경기가 있는 날짜 칸 탭.
  final ValueChanged<DateTime>? onDateTap;

  final CalendarWeekStart weekStart;

  /// 한 칸 높이(스케일 적용 전). 월간 그리드와 같아야 접었다 펼 때 칸 안의
  /// 내용이 늘었다 줄지 않는다.
  static const double rowHeight = 64.0;

  @override
  State<ScheduleWeekCalendar> createState() => _ScheduleWeekCalendarState();
}

class _ScheduleWeekCalendarState extends State<ScheduleWeekCalendar> {
  /// 가운데 기준점. 좌우로 이만큼 주를 넘길 수 있다(±10000주 ≈ ±191년).
  static const int _initialPage = 10000;

  late final PageController _controller = PageController(
    initialPage: _initialPage,
  );

  /// [_initialPage] 가 가리키는 주의 시작일.
  late DateTime _baseWeekStart = _weekStartOf(widget.anchorDate);

  /// 스와이프로 방금 요청한 주. 부모가 이 값을 반영해 내려주는 build 는
  /// '내가 만든 변화'이므로 페이지를 되돌리지 않는다.
  DateTime? _pendingWeekStart;

  /// 외부 변경을 페이지에 반영하려고 우리가 스크롤을 움직이는 중인지.
  /// 그동안의 onPageChanged 는 사용자의 스와이프가 아니므로 무시한다.
  bool _programmaticScroll = false;

  /// [date] 가 속한 주의 시작일(설정된 시작 요일 기준, 00:00).
  DateTime _weekStartOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: widget.weekStart.leadingDays(d)));
  }

  /// 기준 주에서 [delta] 주 떨어진 주의 시작일.
  DateTime _weekAt(int delta) =>
      _baseWeekStart.add(Duration(days: delta * 7));

  @override
  void didUpdateWidget(ScheduleWeekCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _weekStartOf(widget.anchorDate);
    if (target == _weekStartOf(oldWidget.anchorDate) &&
        target == _baseWeekStart) {
      return;
    }

    // 스와이프로 내가 요청한 주가 돌아온 것 — 페이지는 이미 그 자리에 있다.
    if (_pendingWeekStart == target) {
      _pendingWeekStart = null;
      return;
    }
    _pendingWeekStart = null;
    if (target == _baseWeekStart) return;

    // 이미 옮기는 중이면 그 애니메이션이 끝나고 [_recenter] 가 기준을 맞춘
    // 뒤에 다시 판단한다. 중첩해서 animateToPage 를 걸면 둘이 서로를 끊어
    // 중간 위치에서 멈춘다(목록을 빠르게 내리면 주가 연달아 바뀐다).
    if (_programmaticScroll) {
      _retargetTo = target;
      return;
    }
    _animateTo(target);
  }

  /// 애니메이션 중에 들어온 다음 목적지. 지금 것이 끝나면 이어서 간다.
  DateTime? _retargetTo;

  void _animateTo(DateTime target) {
    final delta = target.difference(_baseWeekStart).inDays ~/ 7;
    // 한두 주 차이면 미끄러지듯 이동한다 — 목록을 내리다 주가 넘어가는
    // 경우가 여기 해당하고, 그 방향이 보여야 한다. 그보다 멀면(달 이동 등)
    // 중간 주를 훑는 대신 곧바로 옮긴다.
    if (delta.abs() <= 2 && _controller.hasClients) {
      _programmaticScroll = true;
      _controller
          .animateToPage(
            _initialPage + delta,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _recenter(target));
    } else {
      _recenter(target);
    }
  }

  /// 기준 주를 [weekStart] 로 옮기고 페이지 인덱스를 가운데로 되돌린다.
  /// 화면상 보이는 주는 그대로라 사용자에겐 아무 변화가 없다.
  void _recenter(DateTime weekStart) {
    if (!mounted) return;
    setState(() => _baseWeekStart = weekStart);
    if (_controller.hasClients) {
      _controller.jumpToPage(_initialPage);
    }
    _programmaticScroll = false;

    // 옮기는 동안 새 목적지가 들어와 있었으면 이어서 간다.
    final next = _retargetTo;
    _retargetTo = null;
    if (next != null && next != _baseWeekStart) _animateTo(next);
  }

  void _onPageChanged(int page) {
    if (_programmaticScroll) return;
    final delta = page - _initialPage;
    if (delta == 0) return;
    _pendingWeekStart = _weekAt(delta);
    widget.onWeekShift?.call(delta);
    // 정착한 뒤 기준을 옮겨 둔다. 다음 프레임으로 미루는 이유는 월간
    // 캘린더와 같다 — jumpToPage 가 진행 중인 정착을 끊으면 끝부분만
    // 순간이동한 것처럼 보인다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _programmaticScroll) return;
      _recenter(_weekAt(delta));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// [delta] 주 위치의 한 줄(7칸).
  Widget _buildWeek(int delta, double scale) {
    final start = _weekAt(delta);
    final today = DateTime.now();
    // 한 주가 두 달에 걸칠 수 있어 달마다 따로 조회해 쓴다.
    final cache = <int, Map<int, List<CalendarMatch>>>{};
    Map<int, List<CalendarMatch>> monthData(DateTime date) =>
        cache[date.year * 100 + date.month] ??= widget.matchesOfMonth(
          DateTime(date.year, date.month),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final date = start.add(Duration(days: i));
              final dayMatches = monthData(date)[date.day] ?? const [];
              return Expanded(
                child: CalendarDayCell(
                  date: date,
                  matches: dayMatches,
                  // 경기가 있는 날만 탭 가능. 주 이동은 좌우 스와이프로 한다.
                  onTap: (widget.onDateTap != null && dayMatches.isNotEmpty)
                      ? () => widget.onDateTap!(date)
                      : null,
                  showRightBorder: i != 6,
                  showTopBorder: true,
                  isToday:
                      date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day,
                  isSelected:
                      widget.selectedDate != null &&
                      date.year == widget.selectedDate!.year &&
                      date.month == widget.selectedDate!.month &&
                      date.day == widget.selectedDate!.day,
                  scale: scale,
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekdayHeader(scale: scale, weekStart: widget.weekStart),
          SizedBox(
            height: ScheduleWeekCalendar.rowHeight * scale,
            child: PageView.builder(
              controller: _controller,
              physics: widget.onWeekShift == null
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) =>
                  _buildWeek(index - _initialPage, scale),
            ),
          ),
        ],
      ),
    );
  }
}
