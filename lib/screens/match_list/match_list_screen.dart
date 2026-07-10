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
import '../mypage/mypage_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
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

  /// '오늘(없으면 가장 가까운 과거)' 그룹으로 자동 스크롤하기 위한 상태.
  /// 스크롤은 스케줄이 새로 조회될 때(초기 진입 및 필터 변경 재조회)마다 한 번씩 수행하며,
  /// [_scrolledForVersion] 으로 이미 스크롤한 [MatchListViewModel.scheduleVersion] 을 기억해
  /// 같은 조회 결과에 대해 중복 실행되는 것만 막는다.
  final GlobalKey _todayHeaderKey = GlobalKey();
  int? _scrolledForVersion;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _viewModel.addListener(_maybeInitialScroll);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_maybeInitialScroll);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  /// 스케줄 로드(초기 진입 또는 필터 변경 재조회)가 끝나면 오늘 날짜 그룹으로 스크롤한다.
  /// loadingMore(오늘까지 당기는 prefetch) 도 끝나야 오늘 그룹이 로드돼 있으므로
  /// prefetch 완료까지 기다린다. ('전체' 필터는 최신 페이지가 전부 미래 경기)
  ///
  /// VM notify 뿐 아니라 build 후에도 호출되므로(화면 재생성·notify 유실 대비)
  /// 같은 [MatchListViewModel.scheduleVersion] 에 대해서는 딱 한 번만 스크롤한다.
  /// 필터 변경으로 버전이 올라가면(=_reloadSchedule 재실행) 다시 스크롤을 수행해,
  /// 필터를 바꿔 리스트를 다시 조회할 때도 오늘 날짜로 이동한다.
  void _maybeInitialScroll() {
    if (_scrolledForVersion == _viewModel.scheduleVersion ||
        _viewModel.loadingMatches ||
        _viewModel.loadingMore ||
        _viewModel.schedule.isEmpty) {
      return;
    }
    _scrolledForVersion = _viewModel.scheduleVersion;
    _targetDate = _findTargetDate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
  }

  /// 최신→과거 순 목록에서 오늘 이하(=오늘 또는 가장 가까운 과거)인 첫 그룹의 날짜.
  /// 전부 미래면 가장 가까운(마지막) 그룹으로 폴백한다.
  DateTime? _findTargetDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final schedule = _viewModel.schedule;
    for (final day in schedule) {
      final d = DateTime(day.date.year, day.date.month, day.date.day);
      if (!d.isAfter(today)) return day.date;
    }
    return schedule.isNotEmpty ? schedule.last.date : null;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 대상 그룹 헤더로 스크롤한다.
  ///
  /// ListView.builder 는 lazy 라 아직 안 그려진 항목의 높이를 몰라
  /// maxScrollExtent 가 실제보다 훨씬 작게 잡힌다(예: 실제 14000인데 2900).
  /// 그래서 한 번의 jumpTo 로는 한참 아래의 대상까지 못 간다. 대신:
  /// 1) 대상까지 높이를 어림해 jumpTo(현재 max 로 clamp) → 더 아래 항목이 렌더되며
  ///    maxScrollExtent 가 늘어난다.
  /// 2) 다음 프레임에 반복 → 점진적으로 대상에 접근.
  /// 3) 대상 헤더가 렌더(GlobalKey attach)되면 ensureVisible 로 정밀 정렬 후 종료.
  void _scrollToTarget({int attempt = 0}) {
    final target = _targetDate;
    if (!mounted || target == null || !_scrollController.hasClients) return;

    // 대상 헤더가 그려졌으면 정밀 정렬하고 끝낸다.
    // alignment 0.35: 중앙보다 약간 위. 위로 스크롤 여지가 있음을 노출.
    final ctx = _todayHeaderKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0.35);
      return;
    }

    // 무한 반복 방지.
    const maxAttempts = 40;
    if (attempt >= maxAttempts) return;

    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    const headerH = 38.0;
    const cardH = 140.0;
    var offset = 0.0;
    for (final day in _viewModel.schedule) {
      if (_isSameDate(day.date, target)) break;
      offset += headerH * scale + day.matches.length * cardH * scale;
    }
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0.0, max));
    // 다음 프레임에 다시 시도(렌더 확장으로 max 가 늘어나 점점 아래로 접근).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToTarget(attempt: attempt + 1));
  }

  /// 하단 네비 탭 선택. '경기리스트'를 제외한 탭이면 해당 화면으로 전환한다.
  void _onTabSelected(AppNavTab tab) {
    if (tab == AppNavTab.schedule) {
      Navigator.of(context).pushReplacement(tabRoute(const ScheduleScreen()));
    } else if (tab == AppNavTab.subscription) {
      Navigator.of(
        context,
      ).pushReplacement(tabRoute(const SubscriptionScreen()));
    } else if (tab == AppNavTab.mypage) {
      Navigator.of(context).pushReplacement(tabRoute(const MypageScreen()));
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

    // notify 유실(화면 재생성 중 VM dispose 등)에 대비해 build 후에도 스크롤을
    // 재시도한다. _scrolledForVersion 가드로 같은 조회 결과에 대한 실행은 한 번뿐이다.
    if (_scrolledForVersion != _viewModel.scheduleVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeInitialScroll());
    }

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
                      // 리그 '전체'(ALL)는 팀 스코프가 없어 팀 목록이 '전체'뿐이므로
                      // 팀 멀티셀렉트 필터를 숨긴다.
                      if (_viewModel.selectedLeague !=
                          MatchListViewModel.allLeagueLabel) ...[
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
                            // '전체'는 정렬에서 빼고 항상 맨 앞에 고정(마이구독과 동일).
                            pinned: const {MatchListViewModel.allTeamsLabel},
                            scale: scale,
                          ),
                        ),
                      ],
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
          // 자동 스크롤 대상 헤더에 GlobalKey 를 달아 정확히 맞춘다.
          final key = (_targetDate != null && _isSameDate(item.date, _targetDate!))
              ? _todayHeaderKey
              : null;
          final header = MatchDateHeader(
            label: _relativeLabel(item.date),
            dateText: _formatDate(item.date),
            scale: scale,
          );
          if (!item.isFirst) return KeyedSubtree(key: key, child: header);
          // 첫 헤더 — 우측에 정렬 드롭다운 같이 배치.
          return KeyedSubtree(
            key: key,
            child: Row(
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
            ),
          );
        }
        final m = (item as _CardItem).match;
        return MatchCard(
          matchId: m.matchId,
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
            MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchId: m.matchId, match: m),
            ),
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
