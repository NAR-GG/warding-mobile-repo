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

  /// 사용자가 스포방지를 풀어 스코어를 공개한 경기 ID.
  ///
  /// 카드가 아니라 화면이 들고 있어야 한다 — 목록은 뷰포트를 벗어난 카드를
  /// 파괴했다가 다시 만들기 때문에, 카드 State 에 두면 스크롤로 화면 밖에
  /// 나갔다 돌아온 카드가 다시 가려진다. 날짜를 스와이프해 돌아왔을 때도
  /// 같은 이유로 유지된다.
  final Set<String> _revealedMatchIds = {};

  @override
  void dispose() {
    _pageController.dispose();
    _pager.dispose();
    super.dispose();
  }

  /// 스포방지 토글. 다시 켤 때는 개별로 풀어 둔 카드도 함께 되돌린다 —
  /// 사용자가 기대하는 건 '전부 다시 가려짐'이다.
  void _onSpoilerToggleChanged(bool value) {
    if (value && _revealedMatchIds.isNotEmpty) {
      setState(_revealedMatchIds.clear);
    }
    _pager.setSpoilerPreventionEnabled(value);
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
                  onChanged: _onSpoilerToggleChanged,
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
                        revealedMatchIds: _revealedMatchIds,
                        onSpoilerReveal: (matchId) =>
                            setState(() => _revealedMatchIds.add(matchId)),
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
