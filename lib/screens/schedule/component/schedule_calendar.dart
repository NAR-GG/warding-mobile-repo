import 'package:flutter/material.dart';

import '../../../model/calendar_week_start.dart';
import 'calendar_match.dart';
import 'calendar_month_grid.dart';
import 'calendar_weekday_header.dart';

// CalendarMatch 를 함께 노출 — 이 파일만 import 해도 타입을 쓸 수 있다.
export 'calendar_match.dart';

/// 캘린더의 좌우 스와이프 진행 상태.
///
/// [page] 는 [month] 를 0 으로 둔 스크롤 위치(월 단위 실수)다. 0 이면 기준
/// 달에 정착한 상태, +1 이면 다음 달, -0.4 면 이전 달 쪽으로 40% 진행한
/// 상태. 헤더 월 라벨을 이 값에 물려 그리면 그리드와 타이밍이 어긋나지 않는다.
@immutable
class CalendarScrollProgress {
  const CalendarScrollProgress({required this.month, required this.page});

  /// page 0 에 해당하는 기준 월.
  final DateTime month;

  /// 기준 월로부터의 스크롤 위치(월 단위).
  final double page;

  @override
  bool operator ==(Object other) =>
      other is CalendarScrollProgress &&
      other.month == month &&
      other.page == page;

  @override
  int get hashCode => Object.hash(month, page);
}

/// 월간 경기 캘린더.
///
/// 요일 헤더([CalendarWeekdayHeader])와 월간 그리드([CalendarMonthGrid])로
/// 구성된다. 그리드는 [PageView] 위에 얹혀 있어 좌우로 스와이프하면 손가락을
/// 실시간으로 따라오고, 손을 떼면 가까운 달로 정착(settle)한 뒤에야
/// [onMonthShift] 로 알린다.
///
/// 예전엔 `AnimatedSwitcher` 로 만들었다. 그 구조에서는 손을 떼는 순간
/// ViewModel 의 월이 먼저 바뀌어 헤더 라벨이 즉시 새 달로 튀고, 그리드는
/// 그때부터 300ms 슬라이드를 시작해서 둘의 타이밍이 눈에 띄게 어긋났다.
/// PageView 는 스크롤 진행률([PageController.page])을 노출하므로, 그 값을
/// [scrollProgress] 로 밖에 알려 준다. 헤더가 이 노티파이어를 구독해 월
/// 라벨을 그리면 라벨과 그리드가 항상 같은 프레임에서 함께 움직인다.
class ScheduleCalendar extends StatefulWidget {
  const ScheduleCalendar({
    super.key,
    required this.month,
    required this.matchesByDay,
    this.onMonthShift,
    this.selectedDate,
    this.onDateTap,
    this.weekStart = CalendarWeekStart.monday,
    this.scrollProgress,
  });

  /// 표시할 월 (1일 0시로 정규화된 DateTime).
  final DateTime month;

  /// 일(day) → 그 날의 경기 목록. [month] 의 데이터만 담는다.
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

  /// 스와이프 진행률을 밖으로 알리는 통로.
  ///
  /// 페이지가 스크롤되는 동안 매 프레임 갱신된다. 헤더가 이걸 구독해
  /// [CalendarMonthLabel] 로 월 라벨을 그리면, 라벨이 그리드와 정확히 같은
  /// 프레임·같은 진행률로 움직인다. null 이면 캘린더는 그리드만 그린다.
  final ValueNotifier<CalendarScrollProgress>? scrollProgress;

  @override
  State<ScheduleCalendar> createState() => _ScheduleCalendarState();
}

class _ScheduleCalendarState extends State<ScheduleCalendar> {
  /// PageView 의 가운데 기준점. 이 인덱스가 [ScheduleCalendar.month] 에
  /// 해당하고, 좌우로 이 값만큼 달을 넘길 수 있다. 실질적으로 무한(±10000
  /// 개월 ≈ ±833년)이라 사용자가 끝에 닿을 일은 없다.
  static const int _initialPage = 10000;

  late final PageController _controller = PageController(
    initialPage: _initialPage,
  );

  /// 현재 기준 월. [_initialPage] 가 가리키는 달이다.
  ///
  /// 위젯의 [ScheduleCalendar.month] 를 그대로 쓰지 않는 이유: 스와이프로
  /// 페이지가 넘어가면 컨트롤러의 위치는 이미 옆 페이지에 가 있는데, 곧이어
  /// 부모가 새 month 를 내려준다. 그때 기준을 새 month 로 바꾸면 같은 이동이
  /// 두 번 반영돼 두 달치가 건너뛰어진다. 그래서 기준은 여기서 따로 들고,
  /// 부모가 스와이프 이외의 경로(날짜 피커·필터 초기화)로 월을 바꿨을 때만
  /// 갱신한다.
  late DateTime _baseMonth = widget.month;

  /// 스와이프로 방금 요청한 월. 부모가 이 값을 반영해서 내려주는 build 는
  /// '내가 만든 변화'이므로 페이지를 되돌리지 않는다.
  DateTime? _pendingMonth;

  /// 외부 월 변경을 페이지에 반영하려고 우리가 스크롤을 움직이는 중인지.
  ///
  /// [PageView.onPageChanged] 는 사용자의 스와이프인지 프로그램적 이동인지
  /// 구분해 주지 않는다. 그대로 두면 날짜 피커로 9월을 골랐을 때 우리가 건
  /// animateToPage 가 onPageChanged 를 울려 [ScheduleCalendar.onMonthShift]
  /// 를 한 번 더 내보내고, 부모는 그걸 스와이프로 알아들어 10월까지
  /// 가버린다. 이 플래그가 켜진 동안의 onPageChanged 는 무시한다.
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_publishProgress);
    // 첫 프레임엔 컨트롤러가 아직 뷰포트에 안 붙어 page 가 null 이다.
    // 정착 상태(page 0)를 먼저 알려 헤더가 빈 라벨을 그리지 않게 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishProgress());
  }

  /// 현재 스크롤 위치를 [ScheduleCalendar.scrollProgress] 로 밀어낸다.
  void _publishProgress() {
    final notifier = widget.scrollProgress;
    if (notifier == null || !mounted) return;
    final position =
        _controller.hasClients && _controller.position.haveDimensions
        ? (_controller.page ?? _initialPage.toDouble())
        : _initialPage.toDouble();
    notifier.value = CalendarScrollProgress(
      month: _baseMonth,
      page: position - _initialPage,
    );
  }

  @override
  void didUpdateWidget(ScheduleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.month == oldWidget.month) return;

    // 스와이프로 내가 요청한 월이 돌아온 것 — 페이지는 이미 그 자리에 있다.
    if (_pendingMonth == widget.month) {
      _pendingMonth = null;
      return;
    }

    // 외부(날짜 피커·필터 초기화 등)에서 월이 바뀐 경우. 페이지를 새 달로
    // 옮겨, 그리드와 라벨이 같은 곡선으로 함께 이동하게 한다.
    _pendingMonth = null;
    final target = widget.month;
    final delta = _monthDelta(_baseMonth, target);
    // 한 칸 차이면 스와이프와 같은 느낌으로 애니메이션, 그 이상 멀면
    // 중간 달들을 훑는 대신 곧바로 점프한다.
    if (delta.abs() == 1 && _controller.hasClients) {
      _programmaticScroll = true;
      _controller
          .animateToPage(
            _initialPage + delta,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _recenter(target));
    } else {
      _recenter(target);
    }
  }

  /// 기준 월을 [month] 로 옮기고 페이지 인덱스를 가운데로 되돌린다.
  /// 화면상 보이는 달은 그대로이므로 사용자에겐 아무 변화가 없다.
  void _recenter(DateTime month) {
    if (!mounted) return;
    setState(() => _baseMonth = month);
    if (_controller.hasClients) {
      _controller.jumpToPage(_initialPage);
      _programmaticScroll = false;
    }
    // 인덱스가 이미 가운데면 jumpToPage 가 리스너를 울리지 않는다. 그래도
    // 기준 월은 바뀌었으니 진행률은 직접 다시 알린다.
    _publishProgress();
  }

  void _onPageChanged(int page) {
    // 우리가 건 스크롤이면 월 이동을 알리지 않는다 — 부모가 이미 그 달로
    // 바꿔 놓은 상태라, 알리면 같은 이동이 두 번 반영된다.
    if (_programmaticScroll) return;
    final delta = page - _initialPage;
    if (delta == 0) return;
    final month = _monthAt(delta);
    _pendingMonth = month;
    widget.onMonthShift?.call(delta);
    // 페이지가 정착한 뒤 기준을 옮겨 인덱스를 다시 가운데로 되돌린다.
    // 프레임 중간에 jumpToPage 를 부르면 스크롤 애니메이션과 충돌하므로
    // 다음 프레임으로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recenter(month));
  }

  /// 기준 월에서 [delta] 개월 떨어진 달. DateTime 생성자가 12월 초과·0 이하
  /// 월을 연도까지 정규화한다.
  DateTime _monthAt(int delta) =>
      DateTime(_baseMonth.year, _baseMonth.month + delta);

  /// [from] → [to] 의 개월 차.
  static int _monthDelta(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  @override
  void dispose() {
    _controller.removeListener(_publishProgress);
    _controller.dispose();
    super.dispose();
  }

  /// 페이지 [delta] 위치의 월 그리드. 기준 월(0)이 아닌 이웃 달은 아직
  /// 데이터가 없으므로 날짜 칸만 그린다 — 스와이프로 들어온 뒤 조회가
  /// 끝나면 경기 칩이 채워진다.
  Widget _buildPage(int delta, double scale) {
    final month = _monthAt(delta);
    final matchesByDay = delta == 0 ? widget.matchesByDay : null;
    return CalendarMonthGrid(
      month: month,
      scale: scale,
      weekStart: widget.weekStart,
      selectedDate: widget.selectedDate,
      onDateTap: widget.onDateTap,
      matchesOf: (date) {
        if (matchesByDay == null || date.month != month.month) return const [];
        return matchesByDay[date.day] ?? const [];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekdayHeader(scale: scale, weekStart: widget.weekStart),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              physics: widget.onMonthShift == null
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) =>
                  _buildPage(index - _initialPage, scale),
            ),
          ),
        ],
      ),
    );
  }
}
