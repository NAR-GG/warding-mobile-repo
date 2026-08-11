import 'package:flutter/material.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/load_error.dart';
import '../../components/nar_banner.dart';
import '../../model/notice.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/schedule/filter_viewmodel.dart';
import '../../viewmodel/schedule/schedule_viewmodel.dart';
import '../match_day/match_day_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../notice/notice_detail_screen.dart';
import '../subscription/subscription_screen.dart';
import 'component/filter_sheet.dart';
import 'component/month_picker_sheet.dart';
import 'component/schedule_calendar.dart';
import 'component/schedule_calendar_skeleton.dart';
import 'component/schedule_header.dart';

/// 경기 일정 페이지. 하단 네비 '경기일정' 탭에 해당한다.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.widgetAction, this.initialMonth});

  /// 위젯 딥링크 액션: 'prev' (이전 달), 'next' (다음 달), 'filter' (필터 모달).
  final String? widgetAction;

  /// 위젯에서 이동할 타겟 월. null 이면 현재 달.
  final DateTime? initialMonth;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
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
    // 위젯 딥링크 액션 처리: 필터 복원 완료 후 모달 열기
    if (widget.widgetAction == 'filter') {
      void listener() {
        if (!_viewModel.isLoading) {
          _viewModel.removeListener(listener);
          if (mounted) _openFilter();
        }
      }
      _viewModel.addListener(listener);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.dispose();
    super.dispose();
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
      _viewModel.loadCalendar(forceRefresh: true);
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
      ),
    );
    if (picked != null) {
      _viewModel.selectDate(picked);
    }
  }

  /// 헤더 필터 버튼 탭 → 필터 바텀시트. 조회를 누르면 고른 리그·팀으로
  /// 캘린더를 다시 불러온다.
  Future<void> _openFilter() async {
    final result = await showAppBottomSheet<FilterResult>(
      context: context,
      child: FilterSheet(
        initialLeagues: _viewModel.filterLeagues,
        initialTeamIds: _viewModel.filterTeamIds,
      ),
    );
    if (result != null) {
      _viewModel.applyFilter(
        leagues: result.leagues,
        teamIds: result.teamIds,
        resetMonth: result.resetMonth,
      );
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
        builder: (_) => NoticeDetailScreen(notice: notice, showListButton: true),
      ),
    );
  }

  /// 캘린더 영역. 아직 데이터가 하나도 없는 상태(최초 진입·재시도 전)에서
  /// 로딩 중이면 스켈레톤, 조회 실패면 안내+재시도를 보여준다. 그 외(성공해서
  /// 데이터가 있거나, 성공했지만 그 달에 경기가 없는 경우)엔 캘린더 그대로.
  Widget _buildCalendarArea(
    BuildContext context,
    Map<int, List<CalendarMatch>> matchesByDay,
    double scale,
  ) {
    if (_viewModel.matchesByDay.isEmpty) {
      if (_viewModel.isLoading) {
        return ScheduleCalendarSkeleton(scale: scale);
      }
      if (_viewModel.error != null) {
        return LoadError(
          message: '${_viewModel.error}',
          onRetry: _viewModel.loadCalendar,
        );
      }
    }
    return ScheduleCalendar(
      month: _viewModel.displayMonth,
      matchesByDay: matchesByDay,
      onMonthShift: _viewModel.shiftMonth,
      selectedDate: _viewModel.selectedDate,
      onDateTap: _openDay,
    );
  }

  /// 하단 네비 탭 선택. '경기일정'을 제외한 탭이면 해당 화면으로 전환한다.
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.list) {
      Navigator.of(context).pushReplacement(tabRoute(const MatchListScreen()));
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
                final matchesByDay = <int, List<CalendarMatch>>{
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
