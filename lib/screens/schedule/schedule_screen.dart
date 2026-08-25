import 'package:flutter/material.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/guide_popup.dart';
import '../../components/load_error.dart';
import '../../components/nar_banner.dart';
import '../../l10n/app_localizations.dart';
import '../../model/notice.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/schedule/filter_viewmodel.dart';
import '../../viewmodel/schedule/schedule_viewmodel.dart';
import '../community/community_screen.dart';
import '../match_day/match_day_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../notice/notice_detail_screen.dart';
import '../subscription/subscription_screen.dart';
import 'component/filter_sheet.dart';
import '../../util/home_widget_service.dart';
import 'component/month_picker_sheet.dart';
import 'component/schedule_calendar.dart';
import 'component/schedule_calendar_skeleton.dart';
import 'component/schedule_header.dart';

/// 경기 일정 페이지. 하단 네비 '경기일정' 탭에 해당한다.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    } else {
      // 사용 가이드 팝업. 위젯에서 필터를 열려고 들어온 경우엔 띄우지 않는다 —
      // 사용자가 의도한 필터 모달 위에 겹친다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeShowGuidePopup(context);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 내가 등록해 둔 것일 때만 지운다 — 화면이 교체되는 중이면 새 화면이
    // 이미 자기 것으로 덮어썼을 수 있다.
    if (identical(_activeScheduleScreen, this)) {
      _activeScheduleScreen = null;
    }
    _viewModel.dispose();
    super.dispose();
  }

  /// 위젯이 보고 있는 달로 화면을 맞춘다.
  ///
  /// 이번 달이면 아무것도 하지 않는다 — 기본값과 같아서 굳이 다시 불러올
  /// 이유가 없다.
  Future<void> _syncMonthFromWidget() async {
    final month = await HomeWidgetService.widgetDisplayedMonth();
    if (!mounted) return;
    final now = DateTime.now();
    if (month.year == now.year && month.month == now.month) return;
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
    _openFilter();
  }

  /// 필터 모달이 떠 있는지. 같은 딥링크가 연달아 와도 두 장 쌓이지 않게 한다.
  bool _filterSheetOpen = false;

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

  /// 헤더 필터 버튼 탭 → 필터 바텀시트. 조회를 누르면 고른 리그·팀으로
  /// 캘린더를 다시 불러온다.
  Future<void> _openFilter() async {
    _filterSheetOpen = true;
    try {
      await _showFilterSheet();
    } finally {
      _filterSheetOpen = false;
    }
  }

  /// 필터 옵션을 먼저 받고, 성공했을 때만 시트를 띄운다.
  ///
  /// 옵션을 못 받으면 시트가 리그·팀 목록 없이 떠서 선택값이 있어도 '전체/전체'
  /// 로 보이고, 그 상태에서 조회를 누르면 저장된 필터가 '전체'로 덮어써진다.
  /// 빈 시트를 보여주느니 안 열고 안내하는 편이 낫다.
  Future<void> _showFilterSheet() async {
    final filterViewModel = FilterViewModel(
      initialLeagues: _viewModel.filterLeagues,
      initialTeamIds: _viewModel.filterTeamIds,
    );
    try {
      await filterViewModel.firstLoad;
      if (!mounted) return;
      if (filterViewModel.loadFailed) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.filterLoadFailed)),
        );
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

  /// 캘린더에서 경기가 있는 날짜를 탭 → 그 날의 경기 리스트 화면을 새로 띄운다.
  /// 캘린더에 적용 중인 리그·팀 필터를 그대로 넘겨 같은 경기 집합을 보여준다.
  void _openDay(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchDayScreen(
          date: date,
          leagues: _viewModel.filterLeagues,
          teamIds: _viewModel.filterTeamIds,
        ),
      ),
    );
  }

  /// 띠배너 탭 → 공지 상세. 목록을 거치지 않고 왔으므로 목록 이동 아이콘을 켠다.
  void _openNotice(Notice notice) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NoticeDetailScreen(notice: notice, showListButton: true),
      ),
    );
  }

  /// 캘린더 영역. 앱을 켜고 나서 캘린더 조회가 한 번도 성공한 적 없는
  /// 상태(최초 진입·재시도 전)에서만 로딩 스켈레톤·에러 안내를 보여준다.
  /// 그 외(스와이프로 다른 달로 넘어갔지만 아직 그 달 응답을 못 받은 경우
  /// 포함)엔 항상 그리드부터 그린다 — 날짜 칸은 API 응답과 무관하게 그릴 수
  /// 있으니, 응답을 기다리는 동안 그리드를 스켈레톤으로 가릴 이유가 없다.
  /// 경기 칩만 응답이 오는 대로 채워진다.
  Widget _buildCalendarArea(
    BuildContext context,
    Map<int, List<CalendarMatch>> matchesByDay,
    double scale,
  ) {
    if (!_viewModel.hasCalendarLoadedOnce) {
      if (_viewModel.isLoading) {
        return ScheduleCalendarSkeleton(
          month: _viewModel.displayMonth,
          scale: scale,
          weekStart: _viewModel.weekStart,
        );
      }
      if (_viewModel.error != null) {
        return LoadError(
          message: '${_viewModel.error}',
          onRetry: _viewModel.loadCalendar,
        );
      }
    }
    // matchesByDayMonth 가 displayMonth 와 다르면(스와이프 직후, 아직 그
    // 달 응답 전) 신선한 데이터가 없는 것 — 그 상태에서 로딩 중이면 칸마다
    // '경기 없음'이 아니라 '아직 모름'으로 펄스 스켈레톤을 보여준다.
    final matchesFresh = _viewModel.matchesByDayMonth == _viewModel.displayMonth;
    return ScheduleCalendar(
      month: _viewModel.displayMonth,
      matchesByDay: matchesByDay,
      onMonthShift: _viewModel.shiftMonth,
      selectedDate: _viewModel.selectedDate,
      onDateTap: _openDay,
      weekStart: _viewModel.weekStart,
      isLoading: !matchesFresh && _viewModel.isLoading,
    );
  }

  /// 하단 네비 탭 선택. '경기일정'을 제외한 탭이면 해당 화면으로 전환한다.
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
    } else if (tab == AppNavTab.community) {
      Navigator.of(context).pushReplacement(tabRoute(const CommunityScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                // ViewModel 의 캘린더 경기 → 칸 칩용 (home, away) 변환.
                //
                // matchesByDay 는 이전 달 조회 응답을 들고 있을 수 있다(스와이프로
                // displayMonth 는 즉시 바뀌지만 새 조회는 아직 진행 중인 구간).
                // 그 달이 아니면 넘기지 않는다 — 안 그러면 같은 day 값의 칩이
                // 잘못된 달의 날짜 칸에 잠깐 새어 나간다.
                final matchesFresh =
                    _viewModel.matchesByDayMonth == _viewModel.displayMonth;
                final matchesByDay = <int, List<CalendarMatch>>{
                  if (matchesFresh)
                    for (final entry in _viewModel.matchesByDay.entries)
                      entry.key: [
                        for (final m in entry.value)
                          (home: m.blueTeamCode, away: m.redTeamCode),
                      ],
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    ScheduleHeader(
                      monthLabel: _viewModel.monthLabel,
                      onMonthTap: _openMonthPicker,
                      onFilterTap: _openFilter,
                      hasActiveFilter: _viewModel.hasActiveFilter,
                      preferredTeam: _viewModel.preferredTeam,
                      teamSelected: _viewModel.teamSelected,
                      onTeamTap: _viewModel.toggleTeamSelected,
                    ),
                    // 공지 띠배너 — 활성 공지가 있고 ✕로 닫지 않았을 때만.
                    if (_viewModel.promotedNotice != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8 * scale),
                        child: NarBanner(
                          scale: scale,
                          icon: Text(
                            '📢',
                            style: TextStyle(fontSize: 16 * scale),
                          ),
                          text: _viewModel.promotedNotice!.title,
                          onTap: () => _openNotice(_viewModel.promotedNotice!),
                          onClose: _viewModel.dismissPromotedNotice,
                        ),
                      ),
                    // 캘린더가 남은 세로 공간을 채우되, 떠 있는 하단 네비에
                    // 가리지 않도록 네비 footprint(72*scale + 바닥 26 + 간격 8)
                    // 만큼 아래를 띄운다.
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 72 * scale + 34),
                        child: _buildCalendarArea(context, matchesByDay, scale),
                      ),
                    ),
                  ],
                );
              },
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
}
