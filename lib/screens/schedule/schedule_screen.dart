import 'package:flutter/material.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/schedule/filter_viewmodel.dart';
import '../../viewmodel/schedule/schedule_viewmodel.dart';
import '../match_day/match_day_screen.dart';
import '../match_list/match_list_screen.dart';
import '../mypage/mypage_screen.dart';
import '../subscription/subscription_screen.dart';
import 'component/filter_sheet.dart';
import 'component/month_picker_sheet.dart';
import 'component/schedule_calendar.dart';
import 'component/schedule_header.dart';

/// 경기 일정 페이지. 하단 네비 '경기일정' 탭에 해당한다.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleViewModel _viewModel = ScheduleViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 헤더 월 영역 탭 → 날짜 피커 바텀시트. 모달 안 화살표는 모달
  /// 캘린더만 넘기고, 날짜를 고르면 그 날짜를 결과로 모달이 닫힌다.
  /// 고른 날짜의 '월'로 메인 경기 일정을 변경한다.
  Future<void> _openMonthPicker() async {
    final picked = await showAppBottomSheet<DateTime>(
      context: context,
      child: MonthPickerSheet(
        initialMonth: _viewModel.displayMonth,
        filterLeague: _viewModel.filterLeague,
        filterTeamId: _viewModel.filterTeamId,
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
        initialLeague: _viewModel.filterLeague,
        initialTeamId: _viewModel.filterTeamId,
      ),
    );
    if (result != null) {
      _viewModel.applyFilter(
        league: result.league,
        teamId: result.teamId,
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
          league: _viewModel.filterLeague,
          teamId: _viewModel.filterTeamId,
        ),
      ),
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
                    // 캘린더가 남은 세로 공간을 채우되, 떠 있는 하단 네비에
                    // 가리지 않도록 네비 footprint(72*scale + 바닥 26 + 간격 8)
                    // 만큼 아래를 띄운다.
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 72 * scale + 34),
                        child: ScheduleCalendar(
                          month: _viewModel.displayMonth,
                          matchesByDay: matchesByDay,
                          onMonthShift: _viewModel.shiftMonth,
                          selectedDate: _viewModel.selectedDate,
                          onDateTap: _openDay,
                        ),
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
