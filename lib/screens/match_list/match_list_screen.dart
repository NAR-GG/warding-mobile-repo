import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../components/app_bottom_nav.dart';
import '../../components/app_bottom_sheet.dart';
import '../../components/labeled_field.dart';
import '../../components/load_error.dart';
import '../../components/nar_chip_multi_select.dart';
import '../../components/nar_dropdown.dart';
import '../../components/nar_spoiler_toggle.dart';
import '../../components/scroll_to_top_button.dart';
import '../../components/search_select_box.dart';
import '../../model/schedule_match.dart';
import '../../styles/app_colors.dart';
import '../../util/league_icon.dart';
import '../../util/match_status.dart';
import '../../util/match_title_l10n.dart';
import '../../util/tab_route.dart';
import '../../viewmodel/match_list/match_list_viewmodel.dart';
import '../match_detail/match_detail_screen.dart';
import '../mypage/mypage_screen.dart';
import '../schedule/schedule_screen.dart';
import '../subscription/subscription_screen.dart';
import 'component/match_card.dart';
import 'component/match_card_skeleton.dart';
import 'component/match_date_header.dart';
import 'component/match_league_header.dart';

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

  /// 사용자가 스포방지를 풀어 스코어를 공개한 경기 ID.
  ///
  /// 카드가 아니라 화면이 들고 있어야 한다 — [ListView.builder] 는 뷰포트를
  /// 벗어난 카드를 파괴했다가 다시 만들기 때문에, 카드 State 에 두면 스크롤로
  /// 화면 밖에 나갔다 돌아온 카드가 다시 가려진다.
  final Set<String> _revealedMatchIds = {};

  /// 정렬 드롭다운 행을 접었는지. 목록을 내리면 접고, 올리면 다시 펼친다.
  /// (필터가 늘어나 목록 영역이 좁아진 것에 대한 보정)
  bool _sortBarCollapsed = false;

  /// 마지막으로 방향을 판정한 스크롤 오프셋. 손떨림 수준의 미세한 움직임으로
  /// 접힘/펼침이 깜빡이지 않도록 [_sortBarToggleDelta] 이상 움직였을 때만 반영한다.
  double _lastScrollOffset = 0;

  /// 접힘/펼침을 뒤집는 데 필요한 최소 스크롤 이동량(px).
  static const double _sortBarToggleDelta = 12;

  /// '맨 위로'로 올라가는 중인지. 목록 위쪽 끝(오프셋 0)이 곧 목적지인데,
  /// 도착하면 [_onScroll] 의 과거 이어받기 조건(pixels < 300)에 걸려 과거
  /// 페이지가 앞에 붙고 그만큼 오프셋이 밀려 내려간다. 올라가는 동안에는
  /// 그 트리거를 막는다.
  bool _suppressPrevLoad = false;

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
    // 새로 조회한 목록은 처음부터 다시 보는 셈이라 정렬 행도 펼친 상태로 되돌린다.
    if (_sortBarCollapsed) {
      setState(() => _sortBarCollapsed = false);
    }
    _lastScrollOffset = 0;

    _targetDate = _findTargetDate();
    debugPrint('[MatchList][perf] 데이터 로드 끝, 스크롤 예약 ${DateTime.now()}');
    // 정렬 변경으로 다시 스크롤할 때는 이전 오프셋이 남아 있으면 어림 계산(jumpTo)이
    // 어긋나므로 0(=목록 시작)부터 다시 접근한다.
    if (_scrollController.hasClients && _scrollController.offset != 0) {
      _scrollController.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
  }

  /// 자동 스크롤 대상 날짜 — 오늘 이하(=오늘 또는 가장 가까운 과거)인 그룹.
  /// 전부 미래면 오늘에 가장 가까운 그룹으로 폴백한다.
  ///
  /// '오늘 이후'는 서버가 오늘 이전을 잘라내고 내려주므로 첫 그룹이 곧 대상이다
  /// (오늘 경기가 없으면 가장 가까운 예정일).
  ///
  /// 그 외 정렬은 과거 경기도 함께 오므로 오늘 이하인 첫 그룹을 찾는다. 담긴
  /// 순서는 서버 `sort` 에 따라 과거→미래일 수도, 최신→과거일 수도 있어
  /// ([MatchListViewModel.scheduleAscending]) 방향에 맞춰 훑는다.
  DateTime? _findTargetDate() {
    final schedule = _viewModel.schedule;
    if (schedule.isEmpty) return null;
    if (_viewModel.upcomingOnly) return schedule.first.date;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 과거→미래로 담겼으면 뒤에서부터 훑어야 '오늘 이하 중 가장 늦은 날'을
    // 먼저 만난다(최신→과거면 앞에서부터가 그렇다).
    final ordered = _viewModel.scheduleAscending
        ? schedule.reversed.toList()
        : schedule;
    for (final day in ordered) {
      final d = DateTime(day.date.year, day.date.month, day.date.day);
      if (!d.isAfter(today)) return day.date;
    }
    // 전부 미래면 오늘에 가장 가까운(=가장 이른) 그룹으로 폴백한다.
    return _viewModel.scheduleAscending ? schedule.first.date : schedule.last.date;
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
    if (attempt == 0) {
      debugPrint('[MatchList][perf] _scrollToTarget 시작 ${DateTime.now()}');
    }
    final target = _targetDate;
    if (!mounted || target == null || !_scrollController.hasClients) return;

    // 대상 헤더가 그려졌으면 정밀 정렬하고 끝낸다.
    // 화면 위에서 35% 지점: 중앙보다 약간 위. 위로 스크롤 여지가 있음을 노출.
    final ctx = _todayHeaderKey.currentContext;
    if (ctx != null) {
      debugPrint(
          '[MatchList][perf] _scrollToTarget 완료 attempt=$attempt ${DateTime.now()}');
      Scrollable.ensureVisible(
        ctx,
        duration: Duration.zero,
        alignment: 0.35,
      );
      return;
    }

    // 무한 반복 방지.
    const maxAttempts = 40;
    if (attempt >= maxAttempts) {
      debugPrint('[MatchList][perf] _scrollToTarget 40번 시도 후 포기');
      return;
    }

    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    // 어림 계산용 실제 높이. 틀리면 대상까지 못 가거나 지나쳐서 오늘로 이동이 어긋난다.
    // 헤더: MatchDateHeader 가 height 38 고정.
    // 카드: 위 10 + 헤더행 24 + 간격 20 + 스코어행 77 + 아래 24 = 155.
    // 스코어행은 스포방지 오버레이가 116×77 을 고정으로 잡아서, 팀 컬럼(73)이
    // 아니라 이쪽이 행 높이를 정한다.
    // 리그헤더: '전체' 필터일 때만 날짜 그룹 안에 리그별로 하나씩 더 낀다
    // (MatchLeagueHeader — 위아래 패딩 10*2 + 로고 34 ≈ 54).
    const headerH = 38.0;
    const cardH = 155.0;
    const leagueHeaderH = 54.0;
    final groupByLeague =
        _viewModel.selectedLeague == MatchListViewModel.allLeagueLabel;
    var offset = 0.0;
    for (final day in _viewModel.schedule) {
      if (_isSameDate(day.date, target)) break;
      offset += headerH * scale + day.matches.length * cardH * scale;
      if (groupByLeague) {
        final leagueCount =
            day.matches.map((m) => m.leagueInfo).toSet().length;
        offset += leagueCount * leagueHeaderH * scale;
      }
    }
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    // 어림값은 실제와 어긋날 수 있다(카드 높이가 시안과 달라지거나, 첫 카드의
    // 구분선 유무로 1px 씩 밀리는 등). 어림값이 실제보다 작으면 대상이 화면
    // 아래에 남아 렌더되지 않는데, 다음 프레임에 같은 값을 다시 계산하면
    // 제자리걸음만 하다 포기하게 된다. 그래서 이미 그 지점에 가 있는데도 대상이
    // 안 보이면 한 화면씩 더 내려 반드시 아래로 나아가게 한다.
    final estimated = offset.clamp(0.0, max);
    final stuck = (position.pixels - estimated).abs() < 1;
    final next = stuck
        ? (position.pixels + position.viewportDimension * 0.8).clamp(0.0, max)
        : estimated;
    _scrollController.jumpTo(next);
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
  /// '맨 위로' — 지금 목록의 최상단으로 올린다.
  ///
  /// 재조회하지 않는다. 진입 페이지를 `around=오늘` 로 받는 구조라
  /// ([MatchListViewModel] 참고) 다시 조회해도 목록 앞은 '오늘'이 아니라
  /// '오늘보다 과거 절반'의 시작일 뿐이라, 재조회는 네트워크만 쓰고 사용자가
  /// 있던 자리에서 거의 움직이지 않는다. 이미 받아 둔 목록의 오프셋 0 이
  /// 곧 화면상 맨 위다.
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    if (_sortBarCollapsed) {
      _lastScrollOffset = 0;
      setState(() => _sortBarCollapsed = false);
    }
    // 도착 지점(0)은 과거 이어받기 트리거 구간이기도 하다. 올라가는 동안
    // 과거가 앞에 붙으면 그만큼 아래로 밀려 맨 위에 닿지 못한다.
    _suppressPrevLoad = true;
    _scrollController
        .animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .whenComplete(() {
          if (mounted) _suppressPrevLoad = false;
        });
  }

  /// 스포방지 토글. 다시 켤 때는 개별로 풀어 둔 카드도 함께 되돌린다 —
  /// 사용자가 기대하는 건 '전부 다시 가려짐'이다.
  void _onSpoilerToggleChanged(bool value) {
    if (value && _revealedMatchIds.isNotEmpty) {
      setState(_revealedMatchIds.clear);
    }
    _viewModel.setSpoilerPreventionEnabled(value);
  }

  /// 경기 상세로 이동한다.
  ///
  /// 상세는 pushReplacement 가 아니라 push 라 돌아와도 이 화면의 State 가
  /// 그대로 살아 있다. 접힌 채로 나갔다면 정렬 행이 숨은 상태로 되돌아오는데,
  /// 목록을 다시 보는 시점이니 펼친 상태로 맞춰 준다.
  Future<void> _openMatchDetail(ScheduleMatch m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchDetailScreen(matchId: m.matchId, match: m),
      ),
    );
    if (!mounted || !_sortBarCollapsed) return;
    // 방향 판정 기준점도 지금 위치로 옮긴다 — 그대로 두면 상세를 보는 동안
    // 벌어진 차이가 다음 스크롤 한 번에 몰려 곧바로 다시 접힌다.
    if (_scrollController.hasClients) {
      _lastScrollOffset = _scrollController.offset;
    }
    setState(() => _sortBarCollapsed = false);
  }

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
          for (final order in _viewModel.sortOrders)
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
  /// 함께 스크롤 방향을 보고 정렬 드롭다운 행의 접힘 여부를 갱신한다.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining < 300) {
      _viewModel.loadMoreMatches();
    }
    // 위쪽 끝에 닿으면 과거를 이어받는다. `around=오늘` 진입이라 목록 중간부터
    // 시작한 경우에만 받을 게 있고([MatchListViewModel.hasPrev]), 첫 페이지부터
    // 순서대로 받았다면 VM 이 그냥 무시한다.
    //
    // 자동 스크롤([_scrollToTarget])이 jumpTo 로 0 근처를 지나갈 수 있고,
    // '맨 위로'([_scrollToTop])의 목적지도 0 이라 그 사이에는 트리거하지 않는다.
    if (_scrollController.position.pixels < 300 &&
        !_suppressPrevLoad &&
        _scrolledForVersion == _viewModel.scheduleVersion) {
      _loadPreviousKeepingOffset();
    }
    _updateSortBarVisibility();
  }

  /// 과거 페이지를 받아 목록 앞에 붙이되, 사용자가 보던 위치를 유지한다.
  ///
  /// 위에 항목이 끼어들면 그만큼 콘텐츠가 아래로 밀려, 보고 있던 카드가 화면
  /// 밖으로 튀어나간다. 붙이기 전후의 maxScrollExtent 차이가 곧 늘어난 높이라,
  /// 그만큼 오프셋을 더해 주면 화면에 보이는 내용은 그대로 남는다.
  Future<void> _loadPreviousKeepingOffset() async {
    if (!_viewModel.hasPrev || _viewModel.loadingPrevious) return;
    final before = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    await _viewModel.loadPreviousMatches();

    if (!mounted || !_scrollController.hasClients) return;
    // 새 항목이 실제로 배치된 다음 프레임에 재야 늘어난 높이가 반영돼 있다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final grew = position.maxScrollExtent - before;
      if (grew <= 0) return;
      position.jumpTo(
        (position.pixels + grew).clamp(0.0, position.maxScrollExtent),
      );
    });
  }

  /// 스크롤 방향에 따라 정렬 행을 접거나 편다.
  ///
  /// 목록을 더 보려고 내리면 접고(숨김), 되돌아 올리면 편다(노출).
  ///
  /// 초기 진입·정렬 변경 시의 자동 스크롤([_scrollToTarget])은 jumpTo 를 반복하며
  /// 오프셋이 크게 튀는데, 그 사이 접힘 상태가 흔들리면 목록 높이가 바뀌어
  /// 어림 계산이 어긋난다. 그래서 자동 스크롤이 끝날 때까지는 관여하지 않는다.
  void _updateSortBarVisibility() {
    final offset = _scrollController.offset;
    if (_scrolledForVersion != _viewModel.scheduleVersion ||
        _viewModel.loadingMatches ||
        _viewModel.loadingMore) {
      _lastScrollOffset = offset;
      return;
    }

    final delta = offset - _lastScrollOffset;
    if (delta.abs() < _sortBarToggleDelta) return;
    _lastScrollOffset = offset;

    // 목록 맨 위에서는 항상 펼친 상태로 둔다(오버스크롤 튕김으로 접히는 것 방지).
    final collapsed = offset <= 0 ? false : delta > 0;
    if (collapsed == _sortBarCollapsed) return;
    setState(() => _sortBarCollapsed = collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
                  padding: EdgeInsets.only(
                    left: 20 * scale,
                    right: 20 * scale,
                    top: 17 * scale,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          l.matchList,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      // 시안 폭은 123('스포방지 ON' 기준)이지만 OFF·영문 라벨은
                      // 더 길다. 고정폭을 주면 그만큼 넘쳐 오버플로가 나므로
                      // 내용 폭을 그대로 쓰게 두고 제목이 양보하게 한다.
                      ListenableBuilder(
                        listenable: _viewModel,
                        builder: (context, _) => NarSpoilerToggle(
                          value: _viewModel.spoilerPreventionEnabled,
                          onChanged: _onSpoilerToggleChanged,
                          scale: scale,
                        ),
                      ),
                    ],
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
                                label: l.season,
                                scale: scale,
                                child: SearchSelectBox(
                                  options: MatchListViewModel.seasons,
                                  value: _viewModel.selectedSeason,
                                  onChanged: _viewModel.selectSeason,
                                  sheetTitle: l.season,
                                  scale: scale,
                                ),
                              ),
                            ),
                            SizedBox(width: 10 * scale),
                            Expanded(
                              child: LabeledField(
                                label: l.league,
                                scale: scale,
                                child: SearchSelectBox(
                                  options: _viewModel.leagues,
                                  value: _viewModel.selectedLeague,
                                  onChanged: _viewModel.selectLeague,
                                  sheetTitle: l.league,
                                  hint: _viewModel.loadingLeagues
                                      ? l.loading
                                      : l.select,
                                  labelBuilder: (v) => v == MatchListViewModel.allLeagueLabel ? l.all : v,
                                  leadingBuilder: leagueIconWidget,
                                  scale: scale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 시즌·리그 행 아래 간격 + 구분선.
                      // 구분선은 각 블록이 '자기 아래'만 그린다. 그래야 리그 '전체'로
                      // 팀 셀렉터가 숨어도 정렬 행 위 선이 그대로 남는다.
                      SizedBox(height: 12 * scale),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.narLine,
                      ),
                      // 리그 '전체'(ALL)는 팀 스코프가 없어 팀 목록이 '전체'뿐이므로
                      // 팀 멀티셀렉트 필터를 숨긴다.
                      if (_viewModel.selectedLeague !=
                          MatchListViewModel.allLeagueLabel) ...[
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
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
                            labelBuilder: (v) => v == MatchListViewModel.allTeamsLabel ? l.all : v,
                            scale: scale,
                          ),
                        ),
                      ],
                      // 정렬(최근순/오래된순) — 팀 멀티 셀렉터 아래, 오른쪽 정렬.
                      // 필터가 많아 목록 영역이 좁으므로, 목록을 내리는 동안에는
                      // 위로 말려 들어가고 다시 올리면 펼쳐진다.
                      ClipRect(
                        child: AnimatedAlign(
                          alignment: Alignment.bottomCenter,
                          heightFactor: _sortBarCollapsed ? 0 : 1,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _sortBarCollapsed ? 0 : 1,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 11 * scale,
                                horizontal: 16 * scale,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    width: 110 * scale,
                                    child: NarDropdown(
                                      value: _viewModel.sortOrder,
                                      onTap: _showSortSheet,
                                      scale: scale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _viewModel,
                    builder: (context, _) => _buildList(context, scale),
                  ),
                ),
              ],
            ),
            // 하단 네비(bottom 26 + 높이 72) 위로 띄운다.
            ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) => ScrollToTopButton(
                scrollController: _scrollController,
                scale: scale,
                bottom: 110,
                onPressed: _scrollToTop,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 26,
              // 정렬 행 접힘과 같은 스크롤 방향 판정을 재사용한다 —
              // 한 번의 스와이프에 둘이 함께 반응해야 어색하지 않다.
              child: AppBottomNav(
                currentTab: AppNavTab.list,
                onTabSelected: _onTabSelected,
                compact: _sortBarCollapsed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, double scale) {
    final items = _flatten(_viewModel.schedule);
    final loading = _viewModel.loadingMatches || _viewModel.loadingMore;

    // 결과가 비어있을 때 — 에러면 재시도 안내, 로딩 중이면 스켈레톤, 아니면 빈 상태 메시지.
    if (items.isEmpty) {
      if (_viewModel.error != null) {
        return LoadError(
          message: AppLocalizations.of(context)!.matchLoadFailed,
          onRetry: _viewModel.retryLoadMatches,
        );
      }
      if (loading) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 120 * scale),
          itemCount: 5,
          // 첫 장은 실제 카드와 같이 위 구분선을 끈다(날짜 헤더 아래 첫 카드 규칙).
          itemBuilder: (_, index) =>
              MatchCardSkeleton(scale: scale, showTopBorder: index != 0),
        );
      }
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noMatches,
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
      // 담긴 순서가 곧 화면 순서다(서버 sort). 다음 페이지는 뒤에 append 되므로
      // 스크롤 점프가 없고, _onScroll(maxScrollExtent 근처) 트리거도 그대로 맞는다.
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
          return KeyedSubtree(
            key: key,
            child: MatchDateHeader(
              label: _relativeLabel(context, item.date),
              dateText: _formatDate(context, item.date),
              scale: scale,
            ),
          );
        }
        if (item is _LeagueHeaderItem) {
          return MatchLeagueHeader(leagueName: item.leagueName, scale: scale);
        }
        final m = (item as _CardItem).match;
        // 날짜 헤더·리그 헤더 바로 아래(=화면상 첫 카드)면 위 구분선을 끈다.
        final neighborIndex = index - 1;
        final showTopBorder = !(neighborIndex >= 0 &&
            neighborIndex < items.length &&
            (items[neighborIndex] is _HeaderItem ||
                items[neighborIndex] is _LeagueHeaderItem));
        return MatchCard(
          key: ValueKey('match-${m.matchId}'),
          matchId: m.matchId,
          spoilerRevealed: _revealedMatchIds.contains(m.matchId),
          onSpoilerReveal: () =>
              setState(() => _revealedMatchIds.add(m.matchId)),
          showTopBorder: showTopBorder,
          time: m.scheduledTime,
          label: _localizeMatchTitle(context, m.matchTitle),
          homeName: _shortName(m.teamA),
          awayName: _shortName(m.teamB),
          homeLogoUrl: m.teamA.teamImageUrl,
          awayLogoUrl: m.teamB.teamImageUrl,
          homeCode: m.teamA.teamCode,
          awayCode: m.teamB.teamCode,
          homeScore: m.teamA.score,
          awayScore: m.teamB.score,
          isLive: _isLive(m.matchStatus),
          liveSetLabel: _isLive(m.matchStatus)
              ? AppLocalizations.of(context)!.setInProgress(
                  liveSetNumber(
                    homeScore: m.teamA.score,
                    awayScore: m.teamB.score,
                    setsPlayed: m.sets.length,
                  ),
                )
              : null,
          leagueInfo: m.leagueInfo,
          spoilerPreventionEnabled: _viewModel.spoilerPreventionEnabled,
          onTap: () => _openMatchDetail(m),
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

  /// 날짜 그룹을 헤더+카드 1차원 목록으로 편다.
  /// 담긴 순서가 곧 화면 순서라(서버 sort) 헤더는 항상 그 날짜 카드들 앞에 온다.
  ///
  /// 리그 필터가 '전체'면 여러 리그 경기가 날짜별로 섞여 오므로, 같은 날짜
  /// 안에서 리그별로 다시 묶어(첫 등장 순서 유지) 그 앞에 리그 헤더를 낀다.
  /// 특정 리그를 골랐으면 그 날 경기가 전부 한 리그라 헤더가 무의미해 생략한다.
  List<_ListItem> _flatten(List<ScheduleDay> schedule) {
    final groupByLeague =
        _viewModel.selectedLeague == MatchListViewModel.allLeagueLabel;
    final out = <_ListItem>[];
    for (final day in schedule) {
      out.add(_HeaderItem(day.date));
      if (!groupByLeague) {
        for (final m in day.matches) {
          out.add(_CardItem(m));
        }
        continue;
      }
      final byLeague = <String, List<ScheduleMatch>>{};
      for (final m in day.matches) {
        (byLeague[m.leagueInfo] ??= []).add(m);
      }
      for (final entry in byLeague.entries) {
        out.add(_LeagueHeaderItem(entry.key));
        for (final m in entry.value) {
          out.add(_CardItem(m));
        }
      }
    }
    return out;
  }

  String _shortName(MatchTeam team) =>
      team.teamCode.isNotEmpty ? team.teamCode : team.teamName;

  /// 라이브 판정은 표기 흔들림(`inProgress` 등)을 흡수하는 공용 유틸에 맡긴다.
  bool _isLive(String status) => isLiveMatchStatus(status);

  /// 오늘/어제/내일 만 라벨, 그 외는 빈 문자열.
  String _relativeLabel(BuildContext context, DateTime date) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return l.today;
    if (diff == -1) return l.yesterday;
    if (diff == 1) return l.tomorrow;
    return '';
  }

  String _formatDate(BuildContext context, DateTime d) =>
      AppLocalizations.of(context)!.monthDay(d.month, d.day);

  String _localizeMatchTitle(BuildContext context, String title) =>
      localizeMatchTitle(title, AppLocalizations.of(context)!);
}

sealed class _ListItem {
  const _ListItem();
}

class _HeaderItem extends _ListItem {
  const _HeaderItem(this.date);
  final DateTime date;
}

class _LeagueHeaderItem extends _ListItem {
  const _LeagueHeaderItem(this.leagueName);
  final String leagueName;
}

class _CardItem extends _ListItem {
  const _CardItem(this.match);
  final ScheduleMatch match;
}
