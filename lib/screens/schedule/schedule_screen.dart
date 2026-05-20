import 'package:flutter/material.dart';

import '../../components/app_bottom_nav.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/schedule/schedule_viewmodel.dart';
import 'component/schedule_header.dart';

/// 경기 일정 페이지. 하단 네비 '경기일정' 탭에 해당한다.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ScheduleViewModel _viewModel = ScheduleViewModel();

  /// 하단 네비 현재 탭. 다른 탭 화면 연결 전까지 상태만 보관한다.
  AppNavTab _navTab = AppNavTab.schedule;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Stack(
          children: [
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    ScheduleHeader(monthLabel: _viewModel.monthLabel),
                    // TODO: 월간 캘린더 / 경기 목록
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
                currentTab: _navTab,
                onTabSelected: (tab) => setState(() => _navTab = tab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
