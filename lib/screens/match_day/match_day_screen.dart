import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../components/nar_detail_header.dart';
import '../../components/nar_spoiler_toggle.dart';
import '../../styles/app_colors.dart';
import '../../viewmodel/match_day/match_day_pager_viewmodel.dart';
import 'component/match_day_view.dart';

/// 경기 일정 캘린더에서 특정 날짜를 탭하면 열리는 '그 날의 경기 리스트' 화면.
///
/// 뒤로가기 상세 헤더([NarDetailHeader]) + 경기리스트 탭과 동일한 카드로 구성해 UI 를
/// 일치시킨다. 본문은 [PageView] 로 좌우 스와이프하면 전날/다음날 경기 리스트로 넘어가며,
/// [MatchDayPagerViewModel] 이 항상 `[전날, 현재날, 다음날]` 3페이지 윈도우를 유지한다.
class MatchDayScreen extends StatefulWidget {
  const MatchDayScreen({
    super.key,
    required this.date,
    this.leagues = const ['LCK'],
    this.teamIds,
  });

  final DateTime date;
  final List<String> leagues;
  final List<int>? teamIds;

  @override
  State<MatchDayScreen> createState() => _MatchDayScreenState();
}

class _MatchDayScreenState extends State<MatchDayScreen> {
  late final MatchDayPagerViewModel _pager = MatchDayPagerViewModel(
    initialDate: widget.date,
    leagues: widget.leagues,
    teamIds: widget.teamIds,
  );
  final PageController _pageController = PageController(initialPage: 1);

  @override
  void dispose() {
    _pageController.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == 1) return;
    _pager.shift(index == 2 ? 1 : -1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.jumpToPage(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(
              title: l.matchSchedule,
              centerTitle: false,
              trailing: ListenableBuilder(
                listenable: _pager,
                builder: (context, _) => NarSpoilerToggle(
                  value: _pager.spoilerPreventionEnabled,
                  onChanged: _pager.setSpoilerPreventionEnabled,
                  // 헤더 슬롯 높이가 34 라 시안 패딩 8(총 38)은 세로로 넘친다.
                  verticalPadding: 0,
                  scale: scale,
                ),
              ),
              scale: scale,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _pager,
                builder: (context, _) => PageView.builder(
                  controller: _pageController,
                  itemCount: 3,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final page = _pager.pages[index];
                    return ListenableBuilder(
                      listenable: page,
                      builder: (context, _) => MatchDayView(
                        date: _pager.dates[index],
                        viewModel: page,
                        spoilerPreventionEnabled:
                            _pager.spoilerPreventionEnabled,
                        scale: scale,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
