import 'package:flutter/material.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/labeled_field.dart';
import '../../components/search_select_box.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/match_list/match_list_viewmodel.dart';
import '../schedule/schedule_screen.dart';

/// 경기 리스트 페이지. 하단 네비 '경기리스트' 탭에 해당한다.
class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  final MatchListViewModel _viewModel = MatchListViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 하단 네비 탭 선택. '경기일정'이면 해당 화면으로 전환한다.
  /// '경기리스트'는 현재 화면, '마이 구독'·'마이페이지'는 화면 미구현.
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 페이지 타이틀 — 왼쪽 20, 위 17 여백.
                Padding(
                  padding: EdgeInsets.only(left: 20 * scale, top: 17 * scale),
                  child: Text(
                    '경기리스트',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w700,
                      fontSize: 22 * scale,
                      height: 1.4, // 140%
                      letterSpacing: 0,
                      color: AppColors.narText,
                    ),
                  ),
                ),
                SizedBox(height: 14 * scale), // 타이틀 ↔ 시즌 필드 간격 14
                // 시즌 선택 — 라벨 + 검색 선택 박스.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                  child: ListenableBuilder(
                    listenable: _viewModel,
                    builder: (context, _) => LabeledField(
                      label: '시즌',
                      scale: scale,
                      child: SearchSelectBox(
                        options: MatchListViewModel.seasons,
                        value: _viewModel.selectedSeason,
                        onChanged: _viewModel.selectSeason,
                        scale: scale,
                      ),
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
                currentTab: AppNavTab.list,
                onTabSelected: _onTabSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
