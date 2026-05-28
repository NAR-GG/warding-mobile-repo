import 'package:flutter/material.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/labeled_field.dart';
import '../../components/nar_chip_multi_select.dart';
import '../../components/nar_dropdown.dart';
import '../../components/search_select_box.dart';
import '../../model/schedule_match.dart';
import '../../styles/app_colors.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/match_list/match_list_viewmodel.dart';
import '../match_detail/match_detail_screen.dart';
import '../schedule/schedule_screen.dart';
import 'component/match_card.dart';
import 'component/match_card_skeleton.dart';
import 'component/match_date_header.dart';

/// 경기 리스트 페이지. 하단 네비 '경기리스트' 탭에 해당한다.
class MatchListScreen extends StatefulWidget {
  const MatchListScreen({super.key});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  final MatchListViewModel _viewModel = MatchListViewModel();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

  /// 정렬 옵션 선택 바텀시트.
  Future<void> _showSortSheet() async {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final current = _viewModel.sortOrder;
    final selected = await showAppBottomSheet<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final order in MatchListViewModel.sortOrders)
            InkWell(
              onTap: () => Navigator.of(context).pop(order),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 14 * scale,
                ),
                child: Text(
                  order,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: order == current
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 16 * scale,
                    color: order == current
                        ? AppColors.narText
                        : AppColors.narText2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (selected != null) _viewModel.selectSortOrder(selected);
  }

  /// 스크롤이 끝에서 300px 이내면 이전 7일 추가 fetch.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining < 300) {
      _viewModel.loadMoreMatches();
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
                Padding(
                  padding: EdgeInsets.only(left: 20 * scale, top: 17 * scale),
                  child: Text(
                    '경기리스트',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontWeight: FontWeight.w700,
                      fontSize: 22 * scale,
                      height: 1.4,
                      letterSpacing: 0,
                      color: AppColors.narText,
                    ),
                  ),
                ),
                SizedBox(height: 14 * scale),
                ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LabeledField(
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
                            SizedBox(width: 10 * scale),
                            Expanded(
                              child: LabeledField(
                                label: '리그',
                                scale: scale,
                                child: SearchSelectBox(
                                  options: _viewModel.leagues,
                                  value: _viewModel.selectedLeague,
                                  onChanged: _viewModel.selectLeague,
                                  hint: _viewModel.loadingLeagues
                                      ? '불러오는 중...'
                                      : '선택',
                                  scale: scale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.narLine,
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: AppColors.narLine,
                              width: 1,
                            ),
                          ),
                        ),
                        child: NarChipMultiSelect(
                          options: _viewModel.teams,
                          selectedValues: _viewModel.selectedTeams,
                          onChanged: _viewModel.updateSelectedTeams,
                          scale: scale,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _viewModel,
                    builder: (context, _) => _buildList(scale),
                  ),
                ),
              ],
            ),
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

  Widget _buildList(double scale) {
    final items = _flatten(_viewModel.schedule);
    final loading = _viewModel.loadingMatches || _viewModel.loadingMore;

    // 결과가 비어있을 때 — 로딩 중이면 스켈레톤, 아니면 빈 상태 메시지.
    if (items.isEmpty) {
      if (loading) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 120 * scale),
          itemCount: 5,
          itemBuilder: (_, _) => MatchCardSkeleton(scale: scale),
        );
      }
      return Center(
        child: Text(
          '경기가 없어요',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14 * scale,
            color: AppColors.narText2,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: 120 * scale),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) return _buildFooter(scale);
        final item = items[index];
        if (item is _HeaderItem) {
          final header = MatchDateHeader(
            label: _relativeLabel(item.date),
            dateText: _formatDate(item.date),
            scale: scale,
          );
          if (!item.isFirst) return header;
          // 첫 헤더 — 우측에 정렬 드롭다운 같이 배치.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: header),
              Padding(
                padding: EdgeInsets.only(right: 16 * scale),
                child: SizedBox(
                  width: 110 * scale,
                  child: NarDropdown(
                    value: _viewModel.sortOrder,
                    onTap: _showSortSheet,
                    scale: scale,
                  ),
                ),
              ),
            ],
          );
        }
        final m = (item as _CardItem).match;
        return MatchCard(
          time: m.scheduledTime,
          label: m.matchTitle,
          homeName: _shortName(m.teamA),
          awayName: _shortName(m.teamB),
          homeLogoUrl: m.teamA.teamImageUrl,
          awayLogoUrl: m.teamB.teamImageUrl,
          homeScore: m.teamA.score,
          awayScore: m.teamB.score,
          isLive: _isLive(m.matchStatus),
          liveSetLabel: _isLive(m.matchStatus)
              ? 'SET ${(m.sets.length).clamp(1, 99)} 진행중'
              : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MatchDetailScreen()),
          ),
          scale: scale,
        );
      },
    );
  }

  Widget _buildFooter(double scale) {
    if (_viewModel.loadingMore) {
      return Column(
        children: [
          MatchCardSkeleton(scale: scale),
          MatchCardSkeleton(scale: scale),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  /// schedule(날짜별 그룹) 을 [_HeaderItem, _CardItem, ...] 평탄화.
  /// 첫 번째 헤더에는 isFirst 플래그를 줘서 정렬 드롭다운을 같이 그리게 한다.
  List<_ListItem> _flatten(List<ScheduleDay> schedule) {
    final out = <_ListItem>[];
    var isFirst = true;
    for (final day in schedule) {
      out.add(_HeaderItem(day.date, isFirst: isFirst));
      isFirst = false;
      for (final m in day.matches) {
        out.add(_CardItem(m));
      }
    }
    return out;
  }

  String _shortName(MatchTeam team) =>
      team.teamCode.isNotEmpty ? team.teamCode : team.teamName;

  /// matchStatus 값이 'live'/'in_progress'/'ongoing' 이면 라이브로 본다 (대소문자 무시).
  bool _isLive(String status) {
    final s = status.toLowerCase();
    return s == 'live' || s == 'in_progress' || s == 'ongoing';
  }

  /// 오늘/어제/내일 만 한국어 라벨, 그 외는 빈 문자열.
  String _relativeLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return '오늘';
    if (diff == -1) return '어제';
    if (diff == 1) return '내일';
    return '';
  }

  String _formatDate(DateTime d) => '${d.month}월 ${d.day}일';
}

sealed class _ListItem {
  const _ListItem();
}

class _HeaderItem extends _ListItem {
  const _HeaderItem(this.date, {this.isFirst = false});
  final DateTime date;

  /// 리스트의 첫 헤더면 우측에 정렬 드롭다운을 같이 배치한다.
  final bool isFirst;
}

class _CardItem extends _ListItem {
  const _CardItem(this.match);
  final ScheduleMatch match;
}
