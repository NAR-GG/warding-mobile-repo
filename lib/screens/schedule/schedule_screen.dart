import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/load_error.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/match_list/match_list_viewmodel.dart';
import '../../viewmodel/schedule/filter_viewmodel.dart';
import '../../viewmodel/schedule/schedule_viewmodel.dart';
import '../match_day/match_day_screen.dart';
import '../match_list/component/match_list_view.dart';
import 'component/calendar_month_label.dart';
import 'component/filter_sheet.dart';
import '../../util/home_widget_service.dart';
import 'component/month_picker_sheet.dart';
import 'component/schedule_calendar.dart';
import 'component/schedule_calendar_skeleton.dart';
import 'component/schedule_header.dart';
import 'component/schedule_week_calendar.dart';
import 'component/schedule_list_filter_sheet.dart';
import '../../util/nav_tab_navigation.dart';
import '../../util/analytics_events.dart';
import '../../util/analytics_route_observer.dart';

/// 경기 일정 페이지. 하단 네비 '경기' 탭에 해당한다.
///
/// 캘린더와 경기 리스트가 **한 화면에 세로로 함께** 있다. 예전에는 하단 네비의
/// 두 탭('경기일정'·'경기리스트')으로 나뉘어 있었는데, 둘 다 '어떤 경기가 언제
/// 있나'를 보는 화면이라 탭을 왕복하게 만드는 것이 부자연스러웠다.
///
/// 위쪽 캘린더는 **월간 ↔ 주간**으로 접었다 편다. 월간은 한 달을 조망하고,
/// 주간으로 접으면 그만큼 아래 리스트가 넓어진다. 접고 펴도 리스트는 그대로
/// 유지된다 — 리스트는 날짜에 종속되지 않은 연속 목록이라, 캘린더 높이는
/// '얼마나 넓게 보고 싶은가'의 문제일 뿐이다.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.initialMonth});

  /// 위젯에서 이동할 타겟 월. null 이면 현재 달.
  final DateTime? initialMonth;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

/// 현재 화면에 떠 있는 일정 화면에 "필터를 열어라"를 전달하는 창구.
///
/// 위젯 필터 딥링크는 화면을 새로 만들 필요가 없다. 예전에는 딥링크마다
/// [ScheduleScreen] 을 새로 push/pushReplacement 했는데, 그러면 라우트 교체
/// 전환 도중에 모달을 열게 되어 모달이 곧바로 함께 걷혔다(필터가 안 열리고
/// 캘린더만 다시 뜨던 증상). 이미 있는 화면에 신호만 보낸다.
/// 현재 살아 있는 일정 화면. 딥링크가 이 화면에 필터를 열라고 요청한다.
///
/// 클로저가 아니라 State 를 직접 들고 있어야 한다 — 메서드 tear-off 는 참조할
/// 때마다 새 객체라 `identical` 비교가 항상 false 가 되고, 그러면 dispose 때
/// 정리가 안 돼 죽은 화면의 창구가 남는다.
_ScheduleScreenState? _activeScheduleScreen;

/// 화면이 아직 없을 때 들어온 "필터 열기" 요청. 화면이 준비되면 소비한다.
bool _filterRequestedBeforeReady = false;

/// 일정 화면이 떠 있으면 그 화면의 필터 모달을 열고 true 를 돌려준다.
///
/// 아직 화면이 없으면 요청을 기억해 두고 false 를 돌려준다 — 호출부가 화면을
/// 만들고, 그 화면이 [initState] 에서 이 요청을 소비한다.
bool openScheduleFilterIfVisible() {
  final screen = _activeScheduleScreen;
  if (screen == null || !screen.mounted) {
    _filterRequestedBeforeReady = true;
    return false;
  }
  screen._openFilterFromWidget();
  return true;
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with WidgetsBindingObserver {
  late final ScheduleViewModel _viewModel = ScheduleViewModel(
    initialMonth: widget.initialMonth,
  );

  /// 아래 경기 리스트의 ViewModel.
  ///
  /// 리스트 뷰가 아니라 화면이 들고 있다 — 헤더의 필터 버튼이 리스트 필터
  /// 시트를 열어야 하고(시즌·리그·팀·정렬), 스포방지 토글도 헤더에 있어서
  /// 둘 다 이 VM 을 직접 봐야 한다.
  late final MatchListViewModel _listViewModel = MatchListViewModel();

  /// 지금 캘린더가 어느 단계인지. 진입 시엔 월간.
  _CalendarMode _calendarMode = _CalendarMode.month;

  /// 캘린더가 주간으로 접혀 있는지(숨김 포함). 높이·레이아웃 분기에 쓴다.
  bool get _calendarCollapsed => _calendarMode != _CalendarMode.month;

  /// 캘린더 좌우 스와이프 진행률. 캘린더가 매 프레임 갱신하고, 헤더의 월
  /// 라벨이 이걸 구독한다 — 라벨이 그리드와 같은 프레임에 같은 진행률로
  /// 움직여야 "날짜만 먼저 바뀌는" 어긋남이 생기지 않는다.
  late final ValueNotifier<CalendarScrollProgress> _calendarProgress =
      ValueNotifier(
        CalendarScrollProgress(month: _viewModel.displayMonth, page: 0),
      );

  @override
  void initState() {
    super.initState();
    AnalyticsRouteObserver.instance.setProvider(AnalyticsPage.schedule, () {
      return {
        AnalyticsProp.month: AnalyticsFormat.month(_viewModel.displayMonth),
        // 리스트가 같은 화면에 있으므로 그 상태도 함께 싣는다 — 예전
        // `match_list` 화면의 `page_view` 가 들고 있던 값들이다.
        AnalyticsProp.sortOrder: AnalyticsFormat.sortOrder(
          _listViewModel.sortOrders.indexOf(_listViewModel.sortOrder),
        ),
        AnalyticsProp.spoilerPrevention:
            _listViewModel.spoilerPreventionEnabled
            ? AnalyticsValue.on
            : AnalyticsValue.off,
      };
    });
    WidgetsBinding.instance.addObserver(this);
    // 캘린더가 보는 달이 바뀌면 아래 목록도 그 달부터 시작하게 맞춘다.
    _viewModel.addListener(_syncListAnchorToMonth);
    // 떠 있는 동안에는 위젯의 필터 요청을 이 화면이 받는다.
    _activeScheduleScreen = this;
    // 위젯에서 다른 달로 넘겨 둔 상태라면 앱도 그 달로 맞춘다. 위젯의 prev/next
    // 는 앱 UI 를 열지 않고 위젯만 갱신하므로, 맞춰 주지 않으면 위젯은 7월인데
    // 앱은 이번 달을 보여 서로 어긋난다.
    if (widget.initialMonth == null) _syncMonthFromWidget();
    // 화면이 준비되기 전에 도착해 [_filterRequestedBeforeReady] 로 남아 있는
    // 요청을 처리한다 — 앱이 뜨는 도중에 요청이 소비되면 그 시점엔 창구가
    // 아직 비어 있어 이 플래그로만 전달된다.
    final wantsFilter = _filterRequestedBeforeReady;
    _filterRequestedBeforeReady = false;
    if (wantsFilter) {
      // 캐시가 있으면 로딩이 아예 일어나지 않아 통지도 오지 않는다
      // (`calendar cache hit`). 리스너만 걸어 두면 그 경우 모달이 영영 열리지
      // 않으므로, 첫 프레임에서 현재 상태를 먼저 확인하고 이미 끝나 있으면
      // 바로 연다. 아직 로딩 중이면 그때 리스너로 넘긴다.
      //
      // 실제로 여는 건 한 프레임 더 미룬다(addPostFrameCallback 안에서 다시
      // addPostFrameCallback) — 이 화면은 위젯 딥링크로 방금 push/pushReplacement
      // 된 참이라, 첫 프레임의 GPU 래스터(캘린더 6주치 그리드+헤더+배너를
      // 처음 그리는 것)와 모달 오픈 애니메이션이 같은 프레임에 겹칠 수 있다.
      // DevTools 로 실측한 결과 이 시점의 프레임 드랍(최악 42ms, GPURasterizer
      // 프레임의 30~40%)은 대부분 하단 네비(LiquidGlass, saveLayer 다발)가
      // 원인이라 이 지연만으로는 크게 개선되지 않았다 — 그래도 겹칠 여지를
      // 줄이는 방향이라 부작용 없이 유지한다. 네비 자체의 렌더 비용은 앱
      // 전역 공용 컴포넌트 문제라 이 화면 범위 밖이다.
      void openWhenReady() {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openFilterFromWidget();
        });
      }

      void listener() {
        if (_viewModel.isLoading) return;
        _viewModel.removeListener(listener);
        openWhenReady();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_viewModel.isLoading) {
          _viewModel.addListener(listener);
        } else {
          openWhenReady();
        }
      });
    }
  }

  @override
  void dispose() {
    AnalyticsRouteObserver.instance.removeProvider(AnalyticsPage.schedule);
    _viewModel.removeListener(_syncListAnchorToMonth);
    WidgetsBinding.instance.removeObserver(this);
    // 내가 등록해 둔 것일 때만 지운다 — 화면이 교체되는 중이면 새 화면이
    // 이미 자기 것으로 덮어썼을 수 있다.
    if (identical(_activeScheduleScreen, this)) {
      _activeScheduleScreen = null;
    }
    _viewModel.dispose();
    _listViewModel.dispose();
    _calendarProgress.dispose();
    super.dispose();
  }

  /// 캘린더가 보는 달을 아래 목록의 시작점으로 넘긴다.
  ///
  /// 같은 달이면 VM 이 무시하므로([MatchListViewModel.setAnchorMonth]) 월이
  /// 아닌 변화(로딩 플래그 등)로 통지가 와도 재조회가 걸리지 않는다.
  void _syncListAnchorToMonth() {
    final month = _viewModel.displayMonth;
    // 목록이 스스로 도달한 달이면 되돌려 보내지 않는다 — 스크롤로 11월에
    // 닿아 캘린더를 11월로 옮긴 건데, 그걸 다시 "11월부터 조회해라"로
    // 되돌리면 보고 있던 목록이 통째로 지워지고 11/1 부터 다시 받는다.
    //
    // 플래그로 '지금 따라가는 중'을 감싸는 방식은 통하지 않는다.
    // `displayMonth` setter 가 동기 notify 뿐 아니라 `loadCalendar` 의
    // **비동기 notify** 도 일으켜서, 그때는 이미 플래그가 꺼져 있다.
    // 그래서 순간이 아니라 '어느 달을 목록이 이미 안다'를 기억한다.
    if (_monthFromList == month) return;
    // 목록이 끌고 간 달이 아니면 사용자가 직접 바꾼 것(스와이프·월 피커·
    // 날짜 탭·위젯)이다. 표식을 지워 다음에 또 걸리지 않게 하고 목록을
    // 그 달로 다시 시작한다.
    _monthFromList = null;
    // 사용자가 고른 달이다. 목록이 그 달에 경기가 없어 다음 달 경기를
    // 보여 주더라도, 캘린더를 그 다음 달로 끌고 가면 안 된다 —
    // 12월을 보려고 넘겼는데 1월로 튀어 버린다([_followListDate] 가
    // 이 값을 보고 자기 변경을 건너뛴다).
    _monthPickedByUser = month;

    // **경기가 없는 달이면 목록을 건드리지 않는다.**
    //
    // 서버는 `from=<그 달 1일>` 로 물으면 그 달이 비어도 **다음 경기**를
    // 내려준다. 그대로 두면 12월로 넘겼는데 목록만 1월로 갈아끼워져,
    // 보고 있던 자리를 잃고 캘린더와도 어긋난다. 빈 달에서는 목록이
    // 그냥 있던 자리에 머무는 편이 낫다.
    //
    // 그 달에 경기가 있는지는 **캘린더 조회가 끝나야** 안다. 아직 모르면
    // 목록을 그대로 두고 기다린다 — 여기서 미리 재조회해 버리면 빈 달로
    // 판명돼도 이미 목록이 다음 달로 갈아끼워진 뒤다. 조회가 끝나면
    // `loadCalendar` 가 다시 통지하므로 그때 이 분기를 지나 진행된다.
    //
    // 조회가 **실패**했으면 기다리지 않는다 — 캐시에 아무것도 안 남아
    // 영영 'loaded' 가 되지 않으므로, 그대로 두면 목록이 멈춘 채 굳는다.
    final waitingForCalendar =
        !_viewModel.isMonthLoaded(month) && _viewModel.error == null;
    if (waitingForCalendar) return;
    if (_viewModel.isMonthEmpty(month)) return;

    _listViewModel.setAnchorMonth(month);
  }

  /// 사용자가 직접 고른 달(스와이프·월 피커·위젯). 목록이 그 달을 벗어난
  /// 내용을 보여 줘도 캘린더는 여기 머문다.
  ///
  /// 사용자가 **목록을 스크롤**하면 그때는 따라가야 하므로 풀어 준다
  /// ([_handleListScroll]).
  DateTime? _monthPickedByUser;

  /// 목록 스크롤이 캘린더를 끌고 간 달. 이 달에 대해서는 반대 방향
  /// (캘린더 → 목록 재조회)을 걸지 않는다.
  DateTime? _monthFromList;

  /// 목록에서 지금 보이는 날짜로 캘린더를 맞춘다.
  ///
  /// 스크롤로 11월 경기까지 내려가면 위 캘린더도 11월로 넘어가고, 주간
  /// 모드면 그 날짜가 든 주로 **옆으로 미끄러진다**.
  ///
  /// 스크롤 중에는 **꼭 필요한 변화만** 반영한다.
  ///
  /// 이 콜백은 스크롤 프레임마다 불린다. 예전엔 매번 [setState] 와
  /// `displayMonth` 대입(→ `loadCalendar`)이 걸려서, 목록을 미는 동안
  /// 캘린더 `PageView` 가 프레임마다 다시 만들어졌다 — 스크롤이 끊기고
  /// 손가락을 따라오지 못했다. 그래서:
  /// - 월이 **실제로 바뀔 때만** 캘린더를 옮긴다.
  /// - 주(week) 추적은 **주간 모드일 때만** 하고, 그나마도 보고 있는 주가
  ///   달라질 때만 [setState] 한다(같은 주 안에서 움직이면 그릴 게 없다).
  void _followListDate(DateTime date) {
    if (!mounted) return;

    // 지금 캘린더가 **경기 없는 달**을 보고 있으면 목록을 따라가지 않는다.
    //
    // 빈 달에서는 목록을 옮기지 않으므로([_syncListAnchorToMonth]) 목록에는
    // **이전 달 내용**이 그대로 남아 있다. 그걸 따라가면 사용자가 방금 넘긴
    // 달에서 도로 끌려 나온다 — 12월로 넘긴 뒤 목록을 조금만 밀어도 11월로
    // 되돌아가는 증상.
    if (_viewModel.isMonthEmpty(_viewModel.displayMonth)) return;

    // 목록이 아직 **옛 달의 내용**을 보여 주는 동안에는 따라가지 않는다.
    //
    // 사용자가 캘린더를 12월로 넘기면 목록은 12/1 부터 다시 조회하는데,
    // 그 응답이 오기 전까지 화면에는 11월 카드가 그대로 남아 있다. 그걸
    // 따라가면 **방금 사용자가 넘긴 달을 11월로 되돌려** 버린다.
    //
    // 목록은 시작 달(anchor)부터 미래로 이어지므로, 그보다 **과거** 날짜가
    // 올라오면 아직 옛 내용이라는 뜻이다. 미래 쪽은 스크롤로 실제 도달한
    // 것이니 그대로 따라간다.
    //
    // 단, **이번 달**은 예외다 — 그때 목록은 `around=오늘` 로 받아 과거
    // 절반도 함께 들어오므로, 시작 달보다 앞선 날짜가 정상적으로 올라온다.
    final anchor = _listViewModel.anchorMonth;
    final now = DateTime.now();
    final anchorIsThisMonth =
        anchor != null && anchor.year == now.year && anchor.month == now.month;
    if (anchor != null &&
        !anchorIsThisMonth &&
        DateTime(date.year, date.month).isBefore(anchor)) {
      return;
    }

    final month = _viewModel.displayMonth;
    if (date.year != month.year || date.month != month.month) {
      // 사용자가 방금 고른 달이면 그대로 둔다. 그 달에 경기가 없어 목록이
      // 다음 달 경기를 보여 주는 경우라, 따라가면 사용자가 보려던 달에서
      // 밀려난다(12월로 넘겼는데 1월로 튀는 증상).
      if (_monthPickedByUser == month) return;
      // 이 달은 목록이 스스로 도달한 것이니, 캘린더가 다시 목록에
      // "그 달부터 받아라" 하고 되돌려 보내지 않게 표시해 둔다.
      _monthFromList = DateTime(date.year, date.month);
      _viewModel.displayMonth = date;
      // 달이 바뀌면 선택 강조는 더 이상 보이는 범위가 아니다. 그대로 두면
      // 주간 캘린더가 그 주에 붙박여 스크롤을 따라오지 못한다.
      _viewModel.clearSelectedDate();
    }

    // 주간 줄이 화면에 없는 동안(월간·숨김)은 어느 주를 비추는지가 드러나지
    // 않는다. 기준 날짜만 조용히 갱신해 두면, 주간으로 돌아올 때 지금 보고
    // 있는 주가 그대로 뜬다. 굳이 매 프레임 재빌드할 이유는 없다.
    if (_calendarMode != _CalendarMode.week) {
      _listAnchorDate = date;
      return;
    }

    // 사용자가 직접 쓸어 고른 주는 목록이 거기 닿을 때까지 지킨다.
    if (_weekPinnedByUser) {
      if (_weekStartOf(date) == _weekStartOf(_weekAnchorDate)) {
        // 목록이 따라왔다 — 이제 다시 스크롤을 따라가도 된다.
        _weekPinnedByUser = false;
      }
      return;
    }

    // 고른 날짜의 주를 벗어나도록 스크롤했으면 선택 강조를 놓아 준다.
    //
    // [_weekAnchorDate] 는 `selectedDate` 를 **가장 먼저** 보므로, 선택이
    // 남아 있는 한 _listAnchorDate 를 아무리 갱신해도 주간 캘린더가 그
    // 주에 붙박인다. 날짜를 탭한 뒤 목록을 내리면 캘린더가 안 따라오는
    // 것이 그 증상이다.
    final selected = _viewModel.selectedDate;
    if (selected != null && _weekStartOf(selected) != _weekStartOf(date)) {
      _viewModel.clearSelectedDate();
    }

    // 보고 있는 '주'가 달라질 때만 다시 그린다. 같은 주 안에서 움직이면
    // 캘린더에 드러날 변화가 없다.
    final before = _weekStartOf(_weekAnchorDate);
    _listAnchorDate = date;
    if (_weekStartOf(_weekAnchorDate) != before) setState(() {});
  }

  /// 목록이 지금 보여 주고 있는 날짜. 주간 모드에서 어느 주를 비출지 정한다.
  ///
  /// [setState] 없이 갱신되는 경우가 있다 — 화면에 드러나지 않는 변화라
  /// 다시 그릴 필요가 없을 때다([_followListDate] 참고).
  DateTime? _listAnchorDate;

  /// 손잡이 화살표로 월간 ↔ 주간을 뒤집는다.
  ///
  /// **월간으로 펴는 길은 이 화살표뿐이다.** 스크롤은 접기만(월간→주간→숨김)
  /// 하고, 되돌릴 때는 주간까지만 올려 준다([_handleListScroll]). 목록을
  /// 조금 올렸다고 캘린더가 월간으로 벌어지면 보던 자리가 통째로 밀린다.
  void _toggleCalendar() => _setMode(
    _calendarMode == _CalendarMode.month
        ? _CalendarMode.week
        : _CalendarMode.month,
  );

  void _setMode(_CalendarMode value) {
    if (_calendarMode == value || !mounted) return;
    setState(() {
      _calendarMode = value;
      // 접고 펴는 건 주 선택과 무관하다. 핀이 남아 있으면 다시 접었을 때
      // 목록과 무관한 옛 주가 비친다.
      _weekPinnedByUser = false;
    });
    // 주간으로 접히면 월간 페이저가 사라져 진행률을 갱신해 줄 주체가 없다.
    // 멈춘 값이 남아 다시 펼 때 옛 달이 비치지 않도록 지금 월로 맞춰 둔다.
    _calendarProgress.value = CalendarScrollProgress(
      month: _viewModel.displayMonth,
      page: 0,
    );
  }

  /// 같은 방향으로 연속해 움직인 스크롤 양. 방향이 바뀌면 리셋한다.
  double _scrollAccumulated = 0;

  /// 접힘/펼침을 뒤집는 데 필요한 최소 스크롤 이동량(px).
  /// 손떨림 수준의 움직임으로 캘린더가 깜빡이지 않게 한다.
  /// 하단 네비 축소([BottomNavShrinkController])와 같은 문턱을 쓴다.
  static const double _collapseToggleDelta = 12;

  /// 주간에서 **숨김**으로 넘어가는 데 필요한 추가 스크롤 양(px).
  ///
  /// 접힘 문턱([_collapseToggleDelta])보다 훨씬 크게 둔다. 두 단계가 같은
  /// 문턱이면 한 번 쓸어내릴 때 월간 → 주간 → 숨김이 연달아 터져 주간
  /// 캘린더가 깜빡이고 사라진다. "목록을 더 보려고 한참 내렸다"는 뜻이
  /// 분명할 때만 캘린더를 비운다.
  static const double _hideScrollDelta = 160;

  /// 목록 스크롤 방향에 따라 캘린더를 접거나 편다.
  ///
  /// 목록을 더 보려고 내리면 주간으로 접어 목록을 넓히고, 맨 위로 되돌아가면
  /// 다시 월간으로 편다. 중간에서 조금 올리는 것만으로 캘린더가 다시 펴지면
  /// 보던 자리가 밀려나므로, **펴는 것은 맨 위에 닿았을 때만** 한다.
  /// 사용자가 목록을 직접 미는 중인지(손을 떼고 미끄러지는 구간 포함).
  bool _userScrolling = false;

  bool _handleListScroll(ScrollNotification n) {
    // 가로 스크롤(캘린더 월 페이저)은 무시한다.
    if (n.metrics.axis != Axis.vertical) return false;

    // 손가락이 닿으면 시작, 완전히 멎으면 끝. 그 사이가 '사용자 스크롤'이다.
    if (n is ScrollStartNotification) {
      _userScrolling = n.dragDetails != null;
      // 사용자가 목록을 직접 밀기 시작했으면 '고른 달' 고정을 푼다 —
      // 이제부터는 보는 위치를 캘린더가 따라가는 게 맞다.
      if (_userScrolling) _monthPickedByUser = null;
      return false;
    }
    if (n is ScrollEndNotification) {
      _userScrolling = false;
      _scrollAccumulated = 0;
      return false;
    }

    if (n is! ScrollUpdateNotification) return false;
    final delta = n.scrollDelta;
    if (delta == null) return false;

    // **사용자가 민 스크롤만** 본다. 진입 직후의 '오늘로 이동'이나 캘린더
    // 날짜 탭처럼 코드가 거는 스크롤([MatchListView] 의 jumpTo·ensureVisible)
    // 을 세면, 화면에 들어오자마자 캘린더가 주간으로 접혀 월간을 볼 기회가
    // 없다.
    //
    // `dragDetails` 만 보면 안 된다 — 손을 떼고 미끄러지는 구간(fling)에도
    // null 이라 그때 접힘이 끊긴다. 드래그가 시작된 뒤부터 멈출 때까지를
    // [_userScrolling] 으로 묶어 그 사이의 움직임을 모두 사용자 것으로 본다.
    if (!_userScrolling) {
      _scrollAccumulated = 0;
      return false;
    }

    // 맨 위에서는 항상 월간으로 되돌린다. 오버스크롤 튕김으로 접히는 것도 막는다.
    if (n.metrics.pixels <= n.metrics.minScrollExtent + 1) {
      _scrollAccumulated = 0;
      _setMode(_CalendarMode.month);
      return false;
    }

    final down = delta > 0;
    if (down == (_scrollAccumulated > 0)) {
      _scrollAccumulated += down ? delta.abs() : -delta.abs();
    } else {
      _scrollAccumulated = down ? delta.abs() : -delta.abs();
    }

    // 내리는 중 — 한 단계씩 접는다. 월간 → 주간 → 숨김.
    if (_scrollAccumulated >= _collapseToggleDelta) {
      if (_calendarMode == _CalendarMode.month) {
        _setMode(_CalendarMode.week);
        // 다음 단계(숨김)는 **다시 그만큼 더** 내려야 넘어간다. 한 번의
        // 플링으로 월간에서 숨김까지 날아가면 주간을 볼 틈이 없다.
        _scrollAccumulated = 0;
      } else if (_calendarMode == _CalendarMode.week &&
          _scrollAccumulated >= _hideScrollDelta) {
        _setMode(_CalendarMode.hidden);
        _scrollAccumulated = 0;
      }
      return false;
    }

    // 올리는 중 — 숨김에서만 주간으로 되돌린다. 월간까지 펴는 건
    // 손잡이 화살표의 몫이다([_toggleCalendar]).
    if (_scrollAccumulated <= -_collapseToggleDelta &&
        _calendarMode == _CalendarMode.hidden) {
      _setMode(_CalendarMode.week);
      _scrollAccumulated = 0;
    }
    return false;
  }

  /// 위젯이 보고 있는 달로 화면을 맞춘다.
  ///
  /// **앱이 이미 보고 있는 달과 같으면** 아무것도 하지 않는다. 예전에는
  /// '이번 달이면 return' 이었는데, 그러면 위젯이 이번 달로 돌아왔을 때
  /// 앱이 다른 달에 머물러 있어도 못 따라간다(복귀 동기화에서 드러난다).
  ///
  /// 이 비교가 곧 **앱 ↔ 위젯 순환을 끊는 지점**이다. 앱이 달을 바꾸면
  /// `loadCalendar` 가 위젯을 그 달로 밀고, 위젯이 바뀌면 복귀 때 이 함수가
  /// 앱을 그 달로 당긴다. 양쪽이 같아지는 순간 더 전파되지 않는다.
  Future<void> _syncMonthFromWidget() async {
    final month = await HomeWidgetService.widgetDisplayedMonth();
    if (!mounted) return;
    final current = _viewModel.displayMonth;
    if (month.year == current.year && month.month == current.month) return;
    _viewModel.displayMonth = month;
  }

  /// 위젯 딥링크로 필터를 연다. 이미 열려 있으면 다시 열지 않는다.
  ///
  /// 일정 화면이 스택에 살아 있어도 최상단이 아닐 수 있다 — 경기 상세·날짜별
  /// 목록처럼 그 위에 뭔가를 push 한 상태(하단 탭 전환은 pushReplacement 라
  /// 여기 해당하지 않는다). 이 경우 지금 보이는 화면은 그대로 두고 필터
  /// 시트만 그 위에 얹으면, 사용자는 엉뚱한 화면에서 필터를 보게 된다.
  /// 위에 쌓인 라우트를 걷어 일정 화면을 앞으로 가져온 뒤에 연다.
  void _openFilterFromWidget() {
    if (!mounted || _filterSheetOpen) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      Navigator.of(context).popUntil((r) => identical(r, route));
    }
    // popUntil 은 이 화면(ScheduleScreen) 은 걷지 않으므로 State 자체는 계속
    // mounted 지만, 만약을 대비해 한 번 더 확인한다.
    if (!mounted) return;
    _openCalendarFilter();
  }

  /// 필터 모달이 떠 있는지. 같은 딥링크가 연달아 와도 두 장 쌓이지 않게 한다.
  bool _filterSheetOpen = false;

  /// 헤더 라벨 진행률을 ViewModel 의 현재 월에 맞춘다. 캘린더가 화면에
  /// 없을 때(스켈레톤·에러) 쓰인다. build 중이므로 통지는 다음 프레임으로
  /// 미룬다 — 빌드 도중 리스너를 깨우면 setState 충돌이 난다.
  void _syncProgressToViewModel() {
    final synced = CalendarScrollProgress(
      month: _viewModel.displayMonth,
      page: 0,
    );
    if (_calendarProgress.value == synced) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calendarProgress.value = synced;
    });
  }

  /// 백그라운드로 갔다 돌아왔을 때 다시 불러온다.
  ///
  /// 조회가 아직 진행 중(로딩 스피너)인 상태로 백그라운드에 들어가면, 실기기는
  /// 프로세스를 완전히 정지시켜 진행 중이던 요청의 타임아웃 타이머까지 같이
  /// 멈춘다. 복귀 후 아무도 다시 요청하지 않으면 화면이 멈춘 스피너 그대로
  /// 남는다 — 그래서 복귀할 때마다 무조건 새로 불러온다(경기 스코어가 실시간으로
  /// 바뀌는 화면이라 어차피 최신화할 가치가 있다).
  ///
  /// 이때 반드시 `forceRefresh` 로 부른다. 그냥 부르면 리포지토리가 백그라운드에서
  /// 같이 얼어붙은 그 진행 중 요청에 합류시켜 버려서, 다시 불러도 똑같이 멈춘
  /// 스피너가 남는다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 백그라운드에 있는 동안 위젯에서 달을 넘겼을 수 있다. 위젯의 prev/next
      // 는 앱 UI 를 열지 않고 위젯만 갱신하므로, 복귀할 때 받아 오지 않으면
      // 위젯은 11월인데 앱은 10월인 채로 갈린다.
      //
      // 반대 방향(앱 → 위젯)은 [ScheduleViewModel.loadCalendar] 가 조회할
      // 때마다 `HomeWidgetService.updateCalendar` 로 밀어 준다. 둘이 맞물려
      // 어느 쪽에서 달을 바꾸든 나머지 한쪽이 따라온다.
      _syncMonthFromWidget();
      _viewModel.loadCalendar(forceRefresh: true);
      // 위젯 필터 버튼으로 돌아온 경우 저장소에 남은 요청을 처리한다.
      HomeWidgetService.consumePendingAction();
    }
  }

  /// 헤더 월 영역 탭 → 날짜 피커 바텀시트. 모달 안 화살표는 모달
  /// 캘린더만 넘기고, 날짜를 고르면 그 날짜를 결과로 모달이 닫힌다.
  /// 고른 날짜의 '월'로 메인 경기 일정을 변경한다.
  Future<void> _openMonthPicker() async {
    final picked = await showAppBottomSheet<DateTime>(
      context: context,
      child: MonthPickerSheet(
        initialMonth: _viewModel.displayMonth,
        filterLeagues: _viewModel.filterLeagues,
        filterTeamIds: _viewModel.filterTeamIds,
        weekStart: _viewModel.weekStart,
      ),
    );
    if (picked != null) {
      _viewModel.selectDate(picked);
    }
  }

  /// 헤더 필터 버튼 탭 → 아래 경기 리스트의 필터 시트(시즌·리그·팀·정렬).
  ///
  /// 화면에서 상시로 보이는 건 리스트라, 필터 버튼이 가리키는 것도 리스트
  /// 필터다. 캘린더 칩의 리그·팀 필터는 위젯 딥링크 전용으로만 남았다
  /// ([_openCalendarFilter]).
  Future<void> _openListFilter() async {
    await showAppBottomSheet<void>(
      context: context,
      child: ScheduleListFilterSheet(viewModel: _listViewModel),
    );
  }

  /// 캘린더(칩)의 리그·팀 필터. 조회를 누르면 고른 리그·팀으로 캘린더를
  /// 다시 불러온다. 위젯의 '필터' 딥링크가 쓴다.
  Future<void> _openCalendarFilter() async {
    _filterSheetOpen = true;
    try {
      await _showCalendarFilterSheet();
    } finally {
      _filterSheetOpen = false;
    }
  }

  /// 필터 옵션을 먼저 받고, 성공했을 때만 시트를 띄운다.
  ///
  /// 옵션을 못 받으면 시트가 리그·팀 목록 없이 떠서 선택값이 있어도 '전체/전체'
  /// 로 보이고, 그 상태에서 조회를 누르면 저장된 필터가 '전체'로 덮어써진다.
  /// 빈 시트를 보여주느니 안 열고 안내하는 편이 낫다.
  Future<void> _showCalendarFilterSheet() async {
    final filterViewModel = FilterViewModel(
      initialLeagues: _viewModel.filterLeagues,
      initialTeamIds: _viewModel.filterTeamIds,
    );
    try {
      await filterViewModel.firstLoad;
      if (!mounted) return;
      if (filterViewModel.loadFailed) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.filterLoadFailed)));
        return;
      }
      final result = await showAppBottomSheet<FilterResult>(
        context: context,
        child: FilterSheet(viewModel: filterViewModel),
      );
      if (result != null) {
        _viewModel.applyFilter(
          leagues: result.leagues,
          teamIds: result.teamIds,
          resetMonth: result.resetMonth,
        );
      }
    } finally {
      filterViewModel.dispose();
    }
  }

  /// 캘린더에서 경기가 있는 날짜를 탭 → 아래 리스트를 그 날짜로 스크롤한다.
  ///
  /// 예전에는 날짜별 경기 목록 화면([MatchDayScreen])을 새로 띄웠다. 지금은
  /// 그 목록이 같은 화면 아래에 이미 있으므로, 화면을 쌓는 대신 그 자리로
  /// 데려간다 — 캘린더와 리스트가 한 화면에 있다는 것이 이 구조의 요점이다.
  void _openDay(DateTime date) {
    // 이웃 달 날짜(예: 8월 그리드 마지막 주의 9월 1~5일)를 탭하면 달력도
    // 그 달로 넘어간다 — selectDate 가 displayMonth 까지 맞춘다(같은 달이면
    // no-op, 한 달 차이면 캘린더가 스와이프와 같은 애니메이션으로 따라온다).
    _viewModel.selectDate(date);
    // 같은 달이면 목록이 그대로라 바로 그 날짜로 간다. 달이 바뀌었으면
    // 목록이 비어 있는데, 그때는 뷰가 이 날짜를 기억해 뒀다가 재조회가
    // 끝나는 대로 데려간다([MatchListView.scrollToDate]).
    _listKey.currentState?.scrollToDate(date);
  }

  final GlobalKey<MatchListViewState> _listKey =
      GlobalKey<MatchListViewState>();

  /// 캘린더 영역. 아직 데이터가 하나도 없는 상태(최초 진입·재시도 전)에서
  /// 로딩 중이면 스켈레톤, 조회 실패면 안내+재시도를 보여준다. 그 외(성공해서
  /// 데이터가 있거나, 성공했지만 그 달에 경기가 없는 경우)엔 캘린더 그대로.
  Widget _buildCalendarArea(
    BuildContext context,
    Map<int, List<CalendarMatch>> Function(DateTime month) matchesOfMonth,
    double scale,
  ) {
    if (_viewModel.matchesByDay.isEmpty) {
      if (_viewModel.isLoading || _viewModel.error != null) {
        // 캘린더가 화면에서 빠진 동안은 진행률을 갱신해 줄 주체가 없다.
        // 그 사이 월이 바뀌면(필터 초기화 등) 헤더 라벨이 옛 달에 멈추므로
        // 여기서 직접 맞춰 준다.
        _syncProgressToViewModel();
        // 주간으로 접힌 상태에서는 6주짜리 스켈레톤·에러 박스를 쓸 수 없다.
        // 그대로 두면 로딩이 뜰 때마다 캘린더가 월간 높이로 벌어졌다 줄어
        // 아래 목록이 통째로 밀린다. 칸 하나 높이로 맞춘다.
        if (_calendarCollapsed) {
          return SizedBox(
            height: ScheduleWeekCalendar.rowHeight * scale,
            child: _viewModel.isLoading
                ? const SizedBox.shrink()
                : LoadError(
                    message: '${_viewModel.error}',
                    onRetry: _viewModel.loadCalendar,
                  ),
          );
        }
        if (_viewModel.isLoading) {
          return ScheduleCalendarSkeleton(
            month: _viewModel.displayMonth,
            scale: scale,
            weekStart: _viewModel.weekStart,
          );
        }
        return LoadError(
          message: '${_viewModel.error}',
          onRetry: _viewModel.loadCalendar,
        );
      }
    }
    // 주간은 전용 위젯을 쓴다 — 페이지 단위가 '주'라 목록을 내려 다음 주로
    // 넘어가면 캘린더가 옆으로 미끄러진다. 월간 페이저는 단위가 '달'이라
    // 같은 컨트롤러로는 두 축이 다툰다.
    if (_calendarCollapsed) {
      return ScheduleWeekCalendar(
        anchorDate: _weekAnchorDate,
        matchesOfMonth: matchesOfMonth,
        onWeekShift: _shiftWeek,
        selectedDate: _viewModel.selectedDate,
        onDateTap: _openDay,
        weekStart: _viewModel.weekStart,
      );
    }
    return ScheduleCalendar(
      month: _viewModel.displayMonth,
      matchesOfMonth: matchesOfMonth,
      onMonthShift: _viewModel.shiftMonth,
      selectedDate: _viewModel.selectedDate,
      onDateTap: _openDay,
      weekStart: _viewModel.weekStart,
      scrollProgress: _calendarProgress,
    );
  }

  /// [date] 가 속한 주의 시작일. 주가 바뀌었는지 비교하는 데 쓴다.
  DateTime _weekStartOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: _viewModel.weekStart.leadingDays(d)));
  }

  /// 주간 캘린더가 비출 주의 기준 날짜.
  /// 우선순위: 고른 날짜 > 목록이 보여 주는 날짜 > 오늘.
  DateTime get _weekAnchorDate =>
      _viewModel.selectedDate ?? _listAnchorDate ?? DateTime.now();

  /// 주간 캘린더를 좌우로 쓸어 주를 넘겼을 때.
  ///
  /// 기준 날짜를 그만큼 옮긴다. 달이 바뀌면 캘린더 월도 따라가고, 아래
  /// 목록도 그 달부터 다시 시작한다([_syncListAnchorToMonth]).
  void _shiftWeek(int delta) {
    final next = _weekAnchorDate.add(Duration(days: delta * 7));
    setState(() {
      _listAnchorDate = next;
      // 사용자가 직접 고른 주다. 그대로 두면 목록 스크롤 리포트가
      // [_listAnchorDate] 를 곧바로 덮어써 스와이프가 한 프레임 만에
      // 되돌아간다 — 목록은 움직이지 않았으니 '보이는 날짜'는 그대로라서다.
      // 목록이 이 주로 따라올 때까지는 사용자의 선택을 지킨다.
      _weekPinnedByUser = true;
    });
    _viewModel.clearSelectedDate();
    if (next.year != _viewModel.displayMonth.year ||
        next.month != _viewModel.displayMonth.month) {
      _viewModel.displayMonth = next;
    }
    // 고른 주의 첫날로 목록을 데려간다. 목록이 그 주에 닿으면 리포트가
    // 같은 주를 돌려주므로 핀은 자연히 풀린다.
    _listKey.currentState?.scrollToDate(next);
  }

  /// 사용자가 주간 캘린더를 직접 쓸어 고른 주인지.
  ///
  /// true 인 동안은 목록 스크롤이 [_listAnchorDate] 를 덮어쓰지 못한다.
  /// 목록이 그 주에 도달하면 풀린다([_followListDate]).
  bool _weekPinnedByUser = false;

  /// 하단 네비 탭 선택. '경기일정'을 제외한 탭이면 해당 화면으로 전환한다.
  void _onTabSelected(AppNavTab tab) =>
      handleNavTabSelected(context, AppNavTab.schedule, tab);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 12 * scale),
                // 헤더 — 월 라벨(+접기 화살표) · 스포방지 · 필터.
                // 헤더는 캘린더 VM 만 구독한다. 목록 VM 은 조회·로딩
                // 플래그로 스크롤 중 수시로 통지하는데, 헤더가 그쪽에서
                // 쓰는 값은 스포방지 하나뿐이다 — 함께 묶으면 목록을 미는
                // 내내 헤더가 통째로 다시 그려진다. 스포방지는 토글
                // 위젯만 따로 구독한다([ScheduleHeader.spoilerListenable]).
                ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => ScheduleHeader(
                    monthLabel: _viewModel.monthLabel,
                    // 월간일 때만 스와이프 진행률에 물린 라벨을 쓴다 —
                    // 그리드와 같은 프레임에 같은 진행률로 움직여야
                    // "날짜만 먼저 바뀌는" 어긋남이 안 생긴다.
                    //
                    // 주간일 때는 null 로 둬 헤더의 기본 [Text] 가 나온다.
                    // 진행률은 월간 페이저가 갱신해 주는 값이라 주간에서는
                    // 접히기 직전 값이 그대로 멈춰 있고, 그 값으로 그리면
                    // 라벨이 옛 달에 머물거나 잘린 채 굳는다.
                    monthLabelWidget: _calendarCollapsed
                        ? null
                        : ValueListenableBuilder(
                            valueListenable: _calendarProgress,
                            builder: (context, progress, _) =>
                                CalendarMonthLabel(
                                  progress: progress,
                                  scale: scale,
                                ),
                          ),
                    onMonthTap: _openMonthPicker,
                    onFilterTap: _openListFilter,
                    hasActiveFilter: _viewModel.hasActiveFilter,
                    spoilerListenable: _listViewModel,
                    spoilerPreventionEnabled: () =>
                        _listViewModel.spoilerPreventionEnabled,
                    onSpoilerChanged: _onSpoilerChanged,
                  ),
                ),
                SizedBox(height: 8 * scale),
                // 캘린더 — 월간(6주) ↔ 주간(1주). 접힘은 높이만 바뀌므로
                // AnimatedSize 로 부드럽게 잇는다.
                ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) {
                    // ViewModel 의 캘린더 경기 → 칸 칩용 (home, away) 변환.
                    // 스와이프 중에는 이웃 달도 그려야 하므로 달을 받아 변환한다.
                    Map<int, List<CalendarMatch>> matchesOfMonth(
                      DateTime month,
                    ) {
                      return {
                        for (final entry
                            in _viewModel.matchesOfMonth(month).entries)
                          entry.key: [
                            for (final m in entry.value)
                              (home: m.blueTeamCode, away: m.redTeamCode),
                          ],
                      };
                    }

                    return AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      // 숨김 단계에서는 캘린더 자리를 아예 비운다. 높이가
                      // 0 으로 줄어드는 것도 AnimatedSize 가 이어 준다.
                      child: _calendarMode == _CalendarMode.hidden
                          ? const SizedBox(width: double.infinity)
                          : _buildCalendarArea(
                              context,
                              matchesOfMonth,
                              scale,
                            ),
                    );
                  },
                ),
                // 캘린더를 끌어올려 접고/내려 펴는 손잡이.
                // 캘린더가 사라진 동안은 접을 것도 없어 함께 숨긴다 —
                // 되돌리는 건 목록을 위로 올리는 쪽이다.
                if (_calendarMode != _CalendarMode.hidden)
                  _CalendarDragHandle(
                    scale: scale,
                    collapsed: _calendarCollapsed,
                    onToggle: _toggleCalendar,
                  ),
                // 아래 경기 리스트 — 남은 공간 전부.
                //
                // 목록을 내리면 캘린더가 알아서 주간으로 접혀 목록이 넓어진다
                // ([_handleListScroll]). 손잡이를 따로 누를 필요가 없다.
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleListScroll,
                    child: MatchListView(
                      key: _listKey,
                      viewModel: _listViewModel,
                      // 목록을 스크롤하면 캘린더가 따라온다.
                      onVisibleDateChanged: _followListDate,
                      // 떠 있는 하단 네비(72*scale + 바닥 26 + 간격 8)에
                      // 마지막 카드가 가리지 않도록 띄운다. 뷰가 내부에서
                      // scale 을 다시 곱하므로 375 기준 값으로 되돌려 넘긴다.
                      listBottomPadding: 72 + 34 / scale,
                    ),
                  ),
                ),
              ],
            ),
            // 공용 하단 네비 — 바닥에서 26px 띄움
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              child: AppBottomNav(
                currentTab: AppNavTab.schedule,
                onTabSelected: _onTabSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 스포방지 토글. 리스트 뷰가 개별로 풀어 둔 카드까지 함께 되돌린다.
  void _onSpoilerChanged(bool value) {
    if (value) _listKey.currentState?.clearRevealed();
    _listViewModel.setSpoilerPreventionEnabled(value);
  }
}

/// 캘린더 아래 월간/주간 손잡이.
///
/// 가운데 화살표가 지금 무엇을 할 수 있는지 알린다 — 월간이면 ▲(접기),
/// 주간이면 ▼(펴기). 탭하거나 세로로 끌어 전환한다. 헤더가 아니라 여기에
/// 둔 이유: 전환되는 대상(캘린더)의 경계에 붙어 있어야 무엇이 접히는지
/// 분명하고, 목록을 보려고 아래로 내리는 손 동선과도 맞는다.
/// 캘린더가 차지하는 단계. 목록을 내릴수록 한 칸씩 줄어든다.
///
/// 내릴 때 `month → week → hidden`, 올릴 때는 `hidden → week` 까지만
/// 되돌린다. 월간으로 펴는 건 손잡이 화살표로만 한다 —
/// 목록을 조금 올렸다고 6주가 펼쳐지면 보던 자리가 밀려난다.
enum _CalendarMode {
  /// 6주 월간 그리드.
  month,

  /// 1주 주간 줄.
  week,

  /// 캘린더 없음 — 헤더 바로 아래부터 목록.
  hidden,
}

class _CalendarDragHandle extends StatelessWidget {
  const _CalendarDragHandle({
    required this.scale,
    required this.collapsed,
    required this.onToggle,
  });

  final double scale;
  final bool collapsed;
  final VoidCallback onToggle;

  /// 전환으로 인정할 최소 세로 드래그 속도(px/s). 손떨림으로 접히지 않게 한다.
  static const double _flingVelocity = 120;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < _flingVelocity) return;
        // 위로(음수) 끌면 접고, 아래로(양수) 끌면 편다. 이미 그 상태면 무시.
        if (v < 0 && !collapsed) onToggle();
        if (v > 0 && collapsed) onToggle();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6 * scale),
        child: Center(
          // 월간이면 ▲(접기), 주간이면 ▼(펴기). chevron-down 하나를
          // 뒤집어 쓴다. 전환이 애니메이션이라 화살표도 같이 돈다.
          child: AnimatedRotation(
            turns: collapsed ? 0 : 0.5,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: SvgPicture.asset(
              'assets/icons/chevron-down.svg',
              width: 20 * scale,
              height: 20 * scale,
              colorFilter: const ColorFilter.mode(
                AppColors.narText4,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
