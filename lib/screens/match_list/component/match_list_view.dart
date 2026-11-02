import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/cheer_ad_banner.dart';
import '../../../components/load_error.dart';
import '../../../model/schedule_match.dart';
import '../../../styles/app_colors.dart';
import '../../../util/match_status.dart';
import '../../../util/match_title_l10n.dart';
import '../../../util/match_detail_router.dart';
import '../../../viewmodel/match_list/match_list_viewmodel.dart';
import 'match_card.dart';
import 'match_card_skeleton.dart';
import 'match_date_header.dart';
import 'match_league_header.dart';
import '../../../util/analytics_events.dart';

/// 무한 스크롤 경기 목록.
///
/// 예전에는 `MatchListScreen` 이 직접 들고 있던 본문이다. 캘린더와 리스트를
/// 한 화면에 세로로 함께 두게 되면서([ScheduleScreen]), 그 호스트 화면이
/// 아래쪽에 얹을 수 있도록 위젯으로 떼어냈다.
///
/// **목록만 그린다.** 시즌·리그·팀 필터와 정렬은 헤더 필터 버튼 뒤의 시트로
/// 옮겼고(`ScheduleListFilterSheet`), 제목·스포방지 행은 호스트 헤더로
/// 올라갔다 — 캘린더와 세로를 나눠 쓰게 되어 상시 노출할 공간이 없다.
///
/// 스크롤 위치와 '스포방지를 푼 카드' 집합은 이 위젯이 들고 있다. 목록
/// 상태(필터·조회 결과)는 호스트가 만든 [MatchListView.viewModel] 에 있다.
class MatchListView extends StatefulWidget {
  const MatchListView({
    super.key,
    required this.viewModel,
    this.listBottomPadding = 120,
    this.onVisibleDateChanged,
  });

  /// 화면 맨 위에 보이는 날짜가 바뀔 때 알린다.
  ///
  /// 위 캘린더가 목록을 따라 같은 달·같은 주를 비추게 하려고 호스트가 쓴다.
  /// 스크롤 도중 자주 불리므로 호스트는 값이 실제로 달라졌을 때만 반응한다.
  final ValueChanged<DateTime>? onVisibleDateChanged;

  /// 목록 상태·로직. 호스트가 만들고 [dispose] 한다.
  ///
  /// 뷰가 직접 만들지 않는 이유: 호스트 화면의 헤더가 같은 VM 을 봐야 한다
  /// (스포방지 토글, 필터 시트). 뷰 안에 숨겨 두면 그 둘을 이어 줄 방법이
  /// 콜백 사다리밖에 없다.
  final MatchListViewModel viewModel;

  /// 목록 아래 여백. 떠 있는 하단 네비에 마지막 카드가 가리지 않도록 호스트가
  /// 자기 레이아웃에 맞춰 넘긴다. (375 기준 값 — 내부에서 scale 을 곱한다)
  final double listBottomPadding;

  @override
  State<MatchListView> createState() => MatchListViewState();
}

class MatchListViewState extends State<MatchListView> {
  MatchListViewModel get _viewModel => widget.viewModel;
  final ScrollController _scrollController = ScrollController();

  /// '오늘(없으면 가장 가까운 과거)' 그룹으로 자동 스크롤하기 위한 상태.
  /// 스크롤은 스케줄이 새로 조회될 때(초기 진입 및 필터 변경 재조회)마다 한 번씩 수행하며,
  /// [_scrolledForVersion] 으로 이미 스크롤한 [MatchListViewModel.scheduleVersion] 을 기억해
  /// 같은 조회 결과에 대해 중복 실행되는 것만 막는다.
  final GlobalKey _todayHeaderKey = GlobalKey();

  /// 날짜 그룹 헤더별 키. [_reportVisibleDate] 가 실제 렌더 위치를 재는 데
  /// 쓴다. 뷰포트 밖 항목은 `currentContext` 가 null 이라 자연히 걸러진다.
  ///
  /// 재조회 때 통째로 비우고([_maybeInitialScroll]), 그 사이에도 목록에
  /// 없어진 날짜는 [_pruneHeaderKeys] 가 솎아낸다 — 무한 스크롤로 반년치를
  /// 받으면 키가 수백 개가 되고, 그만큼 매 스크롤마다 순회가 길어진다.
  final Map<DateTime, GlobalKey> _headerKeys = {};
  int? _scrolledForVersion;
  DateTime? _targetDate;

  /// [_scrollToTarget] 이 jumpTo 를 반복하다 ensureVisible 로 마무리할 때까지,
  /// 자동 스크롤이 진행 중인지.
  ///
  /// 어림 jumpTo 로 한 번 크게 튄 뒤 ensureVisible(alignment: 0.35) 로 다시
  /// 되돌아오는 2단계 이동이라, 그 사이 과거 페이지 이어받기가 끼어들면
  /// 목록 앞이 늘어나 어림 계산이 어긋난다. 끝날 때까지는 막아 둔다.
  bool _autoScrolling = false;

  /// 어림 지점 도착 후 몇 번째로 훑는 중인지. 0 이면 아직 어림값으로 가는 중.
  /// 자동 스크롤이 시작·끝날 때마다 0 으로 되돌린다.
  int _sweep = 0;

  /// 사용자가 스포방지를 풀어 스코어를 공개한 경기 ID.
  ///
  /// 카드가 아니라 이 뷰가 들고 있어야 한다 — [ListView.builder] 는 뷰포트를
  /// 벗어난 카드를 파괴했다가 다시 만들기 때문에, 카드 State 에 두면 스크롤로
  /// 화면 밖에 나갔다 돌아온 카드가 다시 가려진다.
  final Set<String> _revealedMatchIds = {};


  /// 지금 목록에 없는 날짜의 키를 버린다. 목록 길이가 변했을 때만 돈다.
  void _pruneHeaderKeys() {
    if (_headerKeys.length <= _maxHeaderKeys) return;
    final alive = {
      for (final d in _viewModel.schedule) _dayOf(d.date),
    };
    _headerKeys.removeWhere((k, _) => !alive.contains(_dayOf(k)));
  }

  /// 이 수를 넘으면 솎아낸다. 한 화면에 보이는 헤더는 많아야 서넛이라
  /// 넉넉한 값이고, 매번 솎으면 그 비용이 더 든다.
  static const int _maxHeaderKeys = 60;

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 스포방지를 다시 켤 때 개별로 풀어 둔 카드도 함께 되돌린다 —
  /// 사용자가 기대하는 건 '전부 다시 가려짐'이다. 토글이 호스트 헤더에
  /// 있어서 호스트가 부른다.
  void clearRevealed() {
    if (_revealedMatchIds.isEmpty) return;
    setState(_revealedMatchIds.clear);
  }

  /// [date] 그룹으로 목록을 스크롤한다. 캘린더에서 날짜를 탭하면 호스트가
  /// 부른다 — 같은 화면 아래 이미 있는 목록을 그 자리로 데려가는 것이
  /// 캘린더+리스트 한 화면 구조의 요점이다.
  void scrollToDate(DateTime date) {
    // 아직 목록에 없는 날짜면(달이 바뀌어 재조회가 도는 중이거나, 그 날이
    // 아직 안 받은 페이지에 있는 경우) 기억해 두고 조회가 끝나면 간다.
    // 여기서 그냥 돌아서면 캘린더에서 다른 달 날짜를 누른 경우 목록이
    // 그 달 첫 경기에 멈추고 누른 날짜로는 영영 안 간다.
    final has = _viewModel.schedule.any((d) => _isSameDate(d.date, date));
    if (!has) {
      _pendingScrollDate = date;
      // 목록은 '오늘' 근처만 받아 둔 상태라, 같은 달이라도 조금 과거면
      // 아직 안 받은 페이지에 있다. 그 날짜가 올 때까지 위쪽으로 더 받는다.
      // (달이 바뀌는 탭이면 재조회가 돌고, 그쪽은 [_maybeInitialScroll] 이
      //  _pendingScrollDate 를 소비한다.)
      _loadUntilDate(date);
      return;
    }
    _pendingScrollDate = null;

    // setState 로 한 번 그려야 [_todayHeaderKey] 가 새 대상 헤더로 옮겨
    // 붙는다([_buildList] 가 _targetDate 와 비교해 키를 단다). 키가 옮겨간
    // 다음 프레임부터 [_scrollToTarget] 이 그 헤더를 찾을 수 있다.
    setState(() {
      _targetDate = date;
      _autoScrolling = true;
      _sweep = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
  }

  /// 사용자가 캘린더에서 눌렀지만 아직 목록에 없던 날짜.
  /// 재조회가 끝나면 [_maybeInitialScroll] 이 이 날짜로 데려간다.
  DateTime? _pendingScrollDate;

  /// [date] 가 목록에 들어올 때까지 과거 페이지를 이어받는다.
  ///
  /// 진입 조회는 `around=오늘` 이라 목록이 오늘 근처에서 시작한다. 캘린더에서
  /// 그보다 조금 앞선 날짜(같은 달 상순 등)를 누르면 그 날은 아직 안 받은
  /// 페이지에 있어 스크롤할 대상이 없다.
  ///
  /// 받을 게 없어지거나([MatchListViewModel.hasPrev]) 목록이 그 날짜보다
  /// 과거까지 닿으면 멈춘다 — 후자는 **그 날에 경기가 없는 경우**다. 더
  /// 받아도 영영 안 나오므로 거기서 끝낸다.
  Future<void> _loadUntilDate(DateTime date) async {
    const maxPages = 12; // 안전장치: 끝없이 당기지 않는다.
    for (var i = 0; i < maxPages; i++) {
      if (!mounted || _pendingScrollDate != date) return;
      if (!_viewModel.hasPrev) break;

      await _viewModel.loadPreviousMatches();
      if (!mounted || _pendingScrollDate != date) return;

      if (_viewModel.schedule.any((d) => _isSameDate(d.date, date))) {
        scrollToDate(date);
        return;
      }
      // 목록이 이미 그 날짜보다 과거까지 닿았으면 그 날엔 경기가 없다.
      // 서버 날짜에는 시각이 붙어 있으므로 날짜 단위로 잘라 비교한다 —
      // 안 그러면 같은 날인데 시각 차이로 '아직 안 닿았다'가 되어 받을 게
      // 없는데도 12번을 다 돈다.
      final earliest = _viewModel.schedule
          .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
          .fold<DateTime?>(
            null,
            (min, d) => min == null || d.isBefore(min) ? d : min,
          );
      final targetDay = DateTime(date.year, date.month, date.day);
      if (earliest != null && earliest.isBefore(targetDay)) break;
    }
    if (mounted && _pendingScrollDate == date) _pendingScrollDate = null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _viewModel.addListener(_maybeInitialScroll);
  }

  @override
  void dispose() {
    // VM 은 호스트가 만들고 버린다 — 여기서 dispose 하면 호스트 헤더가
    // 죽은 VM 을 보게 된다.
    _viewModel.removeListener(_maybeInitialScroll);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    _sweep = 0;
    _headerKeys.clear();
    _reportedVisibleDate = null;
    _lastReportOffset = 0;
    _autoScrolling = true;

    // 캘린더에서 누른 날짜가 있으면 그쪽이 우선이다. 그 날짜가 새 목록에
    // 실제로 들어왔을 때만 쓰고, 아니면 평소대로 '오늘'로 간다.
    final pending = _pendingScrollDate;
    _pendingScrollDate = null;
    final pendingInList =
        pending != null &&
        _viewModel.schedule.any((d) => _isSameDate(d.date, pending));
    _targetDate = pendingInList ? pending : _findTargetDate();
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
    // 캘린더가 이번 달이 아닌 다른 달을 보고 있으면 '오늘'은 그 목록 안에
    // 없다. 그때는 **그 달의 첫 경기**가 보고 싶은 자리다.
    //
    // 목록 맨 앞(`schedule.first`)을 쓰면 안 된다 — 스크롤로 이전 달을
    // 이미 받아 뒀으면 맨 앞은 그 옛 달이고, 그러면 11월로 넘겼는데
    // 10월 어딘가에 서 있게 된다. 그 달에 속한 날짜 중 가장 이른 것을
    // 직접 고른다.
    final anchor = _viewModel.anchorMonth;
    if (anchor != null &&
        !(anchor.year == now.year && anchor.month == now.month)) {
      DateTime? firstOfMonth;
      for (final day in schedule) {
        if (day.date.year != anchor.year || day.date.month != anchor.month) {
          continue;
        }
        if (firstOfMonth == null || day.date.isBefore(firstOfMonth)) {
          firstOfMonth = day.date;
        }
      }
      if (firstOfMonth != null) return firstOfMonth;
      // 그 달 경기가 아직 안 들어왔으면 받아 둔 범위의 시작으로 폴백한다.
      return _viewModel.scheduleAscending
          ? schedule.first.date
          : schedule.last.date;
    }

    final today = DateTime(now.year, now.month, now.day);
    // 과거→미래로 담겼으면 뒤에서부터 훑어야 '오늘 이하 중 가장 늦은 날'을
    // 먼저 만난다(최신→과거면 앞에서부터가 그렇다).
    final ordered =
        _viewModel.scheduleAscending ? schedule.reversed.toList() : schedule;
    for (final day in ordered) {
      final d = DateTime(day.date.year, day.date.month, day.date.day);
      if (!d.isAfter(today)) return day.date;
    }
    // 전부 미래면 오늘에 가장 가까운(=가장 이른) 그룹으로 폴백한다.
    return _viewModel.scheduleAscending
        ? schedule.first.date
        : schedule.last.date;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// [_estimatedOffsetTo] 결과 캐시와, 그 계산이 딛고 있던 목록 상태.
  ///
  /// 대상까지의 어림 높이는 목록 내용이 그대로면 매번 같은 값이 나온다. 그런데
  /// [_scrollToTarget] 은 대상에 닿을 때까지 프레임마다 다시 부르므로(최대 40회),
  /// 캐시가 없으면 그 사이 목록 전체를 40번 훑는다 — 화면 진입 직후, 즉 가장
  /// 바빠야 할 구간에서 벌어지는 일이라 프레임 드랍으로 그대로 드러났다.
  double? _cachedTargetOffset;
  DateTime? _cachedOffsetTarget;
  int? _cachedOffsetScheduleLength;
  int? _cachedOffsetVersion;

  /// [target] 날짜 그룹의 헤더가 목록 맨 위에서 얼마나 아래에 있을지 어림한다.
  ///
  /// 값이 틀리면 대상까지 못 가거나 지나쳐서 '오늘로 이동'이 어긋난다.
  /// - 헤더: [MatchDateHeader] 가 height 38 고정.
  /// - 카드: 위 10 + 헤더행 24 + 간격 12 + 스코어행 77 + 아래 14 = 137.
  ///   스코어행은 스포방지 오버레이가 116×77 을 고정으로 잡아서, 팀 컬럼(73)이
  ///   아니라 이쪽이 행 높이를 정한다.
  /// - 리그헤더: '전체' 필터일 때만 날짜 그룹 안에 리그별로 하나씩 더 낀다
  ///   ([MatchLeagueHeader] — 위아래 패딩 10*2 + 로고 34 ≈ 54).
  double _estimatedOffsetTo(DateTime target) {
    final schedule = _viewModel.schedule;
    // 무한 스크롤로 페이지가 붙으면 길이가 변한다. 길이와 조회 버전이 그대로면
    // 앞쪽 그룹 구성도 그대로라 이전에 잰 값을 그냥 쓴다.
    if (_cachedTargetOffset != null &&
        _cachedOffsetScheduleLength == schedule.length &&
        _cachedOffsetVersion == _viewModel.scheduleVersion &&
        _cachedOffsetTarget != null &&
        _isSameDate(_cachedOffsetTarget!, target)) {
      return _cachedTargetOffset!;
    }

    const headerH = 38.0;
    const cardH = 137.0;
    const leagueHeaderH = 54.0;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final groupByLeague =
        _viewModel.selectedLeague == MatchListViewModel.allLeagueLabel;
    var offset = 0.0;
    for (final day in schedule) {
      if (_isSameDate(day.date, target)) break;
      offset += headerH * scale + day.matches.length * cardH * scale;
      if (groupByLeague) {
        final leagueCount = day.matches.map((m) => m.leagueInfo).toSet().length;
        offset += leagueCount * leagueHeaderH * scale;
      }
    }

    _cachedTargetOffset = offset;
    _cachedOffsetTarget = target;
    _cachedOffsetScheduleLength = schedule.length;
    _cachedOffsetVersion = _viewModel.scheduleVersion;
    return offset;
  }

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
    if (!mounted || target == null || !_scrollController.hasClients) {
      _endAutoScroll();
      return;
    }

    // 대상 헤더가 그려졌으면 정밀 정렬하고 끝낸다.
    // 화면 위에서 35% 지점: 중앙보다 약간 위. 위로 스크롤 여지가 있음을 노출.
    final ctx = _todayHeaderKey.currentContext;
    if (ctx != null) {
      debugPrint(
        '[MatchList][perf] _scrollToTarget 완료 attempt=$attempt ${DateTime.now()}',
      );
      Scrollable.ensureVisible(ctx, duration: Duration.zero, alignment: 0.35);
      _endAutoScroll();
      return;
    }

    // 무한 반복 방지.
    const maxAttempts = 40;
    if (attempt >= maxAttempts) {
      debugPrint('[MatchList][perf] _scrollToTarget 40번 시도 후 포기');
      _endAutoScroll();
      return;
    }

    final offset = _estimatedOffsetTo(target);
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final estimated = offset.clamp(0.0, max);
    final diff = estimated - position.pixels;

    // 어림 지점에 닿았는데도 대상 헤더가 안 붙었으면, 어림값이 실제와 조금
    // 어긋난 것이다([ListView] 는 뷰포트 밖 항목을 안 그려서 한 화면만
    // 벗어나도 키가 안 붙는다). 거기서부터 **좌우로 번갈아 벌려 가며** 훑는다.
    //
    // 위치로 분기하면 안 된다 — 한 칸 움직이는 순간 '어림값에서 멀어졌다'가
    // 되어 다시 어림값으로 되돌아가고 두 자리를 영원히 오간다(실측:
    // est=6906 ↔ px=7026 에서 40프레임을 다 썼다). 그래서 '몇 번째 훑는
    // 중인지'(_sweep)를 들고 그 값으로 거리를 키운다.
    //
    // 아래·위를 번갈아 보는 이유: 어림값은 광고 배너 높이를 빼고 세어
    // 보통 실제보다 작지만(대상이 아래), 과거 페이지가 앞에 붙은 직후엔
    // 반대로 클 수도 있다. 한쪽만 보면 그 경우를 영영 못 찾는다.
    const nudge = 120.0;
    final double next;
    if (_sweep > 0 || diff.abs() < nudge) {
      _sweep++;
      // 1,2,3,4… → +1칸, -1칸, +2칸, -2칸 … 으로 퍼져 나간다.
      final step = ((_sweep + 1) ~/ 2) * nudge;
      final delta = _sweep.isOdd ? step : -step;
      next = (estimated + delta).clamp(0.0, max);
    } else {
      next = estimated;
    }
    _scrollController.jumpTo(next);
    // 다음 프레임에 다시 시도(렌더 확장으로 max 가 늘어나 점점 아래로 접근).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToTarget(attempt: attempt + 1),
    );
  }

  /// 경기 상세로 이동한다.
  ///
  /// 상세는 pushReplacement 가 아니라 push 라 돌아와도 이 뷰의 State 가
  /// 그대로 살아 있다(스크롤 위치·공개한 카드 유지).
  Future<void> _openMatchDetail(ScheduleMatch m, int position) async {
    // 딥링크(라이브 위젯·푸시)와 같은 창구를 쓴다 — 직접 push 하면 그쪽에서
    // 열린 상세를 못 찾아 같은 경기가 두 장 쌓인다.
    await MatchDetailRouter.open(
      matchId: m.matchId,
      match: m,
      context: context,
      fromPage: AnalyticsPage.matchList,
      cardPosition: position,
    );
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
    // 자동 스크롤([_scrollToTarget])이 jumpTo 로 0 근처를 지나갈 수 있어
    // 그 사이에는 트리거하지 않는다.
    if (_scrollController.position.pixels < 300 &&
        _scrolledForVersion == _viewModel.scheduleVersion) {
      _loadPreviousKeepingOffset();
    }
    _reportVisibleDate();
  }

  /// 자동 스크롤을 끝낸다.
  ///
  /// '보이는 날짜' 리포트의 기준 오프셋도 지금 위치로 맞춘다 — 자동
  /// 스크롤은 오프셋을 크게 옮기므로, 그대로 두면 다음 사용자 스크롤에서
  /// [_reportInterval] 문턱을 이미 넘은 것으로 보이거나(즉시 재계산) 반대로
  /// 한참 움직여야 계산되는 식으로 어긋난다.
  void _endAutoScroll() {
    _autoScrolling = false;
    _sweep = 0;
    if (_scrollController.hasClients) {
      _lastReportOffset = _scrollController.offset;
    }
  }

  /// 마지막으로 호스트에 알린 날짜. 같은 날짜를 반복해 알리지 않는다.
  DateTime? _reportedVisibleDate;

  /// 마지막으로 '보이는 날짜'를 계산한 스크롤 오프셋.
  double _lastReportOffset = 0;

  /// 다시 계산할 최소 스크롤 이동량(px). 카드 한 장(137)의 절반쯤.
  static const double _reportInterval = 60;

  /// 화면 맨 위에 걸린 날짜 그룹을 찾아 호스트에 알린다.
  ///
  /// 실제로 그려진 헤더의 위치를 재서 고른다 — 어림 높이([_estimatedOffsetTo])
  /// 로 역산하면 광고 배너처럼 높이를 모르는 항목 때문에 조금씩 어긋나고,
  /// 그 어긋남이 캘린더 월 이동으로 그대로 드러난다.
  void _reportVisibleDate() {
    final notify = widget.onVisibleDateChanged;
    if (notify == null || !_scrollController.hasClients) return;
    // 자동 스크롤(진입·필터 변경) 중에는 오프셋이 크게 튀므로 중간값을
    // 알리지 않는다 — 캘린더가 엉뚱한 달로 몇 번 튀었다 돌아온다.
    if (_autoScrolling) return;

    // 프레임마다 전체 헤더를 훑고 localToGlobal 을 부르면 스크롤이 무거워진다.
    // 한 칸(헤더+카드) 높이의 절반쯤 움직였을 때만 다시 센다 — 그보다 작게
    // 움직여서 '맨 위에 걸린 날짜'가 바뀌는 일은 없다.
    final offset = _scrollController.offset;
    if ((offset - _lastReportOffset).abs() < _reportInterval) return;
    _lastReportOffset = offset;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final listTop = box.localToGlobal(Offset.zero).dy;

    // 목록 위쪽 경계를 **이미 지난** 헤더 중 가장 아래 것이 지금 걸려 있는
    // 날짜다. 하나도 없으면(맨 위라 아직 아무 헤더도 안 지나갔으면) 화면에
    // 보이는 것 중 **가장 위**의 헤더를 쓴다.
    DateTime? passed; // dy <= 0 중 가장 큰 dy
    var passedDy = double.negativeInfinity;
    DateTime? upcoming; // dy > 0 중 가장 작은 dy
    var upcomingDy = double.infinity;

    for (final entry in _headerKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue; // 뷰포트 밖 — 아직/이미 안 그려졌다.
      final headerBox = ctx.findRenderObject();
      if (headerBox is! RenderBox || !headerBox.hasSize) continue;
      final dy = headerBox.localToGlobal(Offset.zero).dy - listTop;
      if (dy <= 0) {
        if (dy > passedDy) {
          passedDy = dy;
          passed = entry.key;
        }
      } else if (dy < upcomingDy) {
        upcomingDy = dy;
        upcoming = entry.key;
      }
    }

    // 맵 순회 순서에 기대면 안 된다 — 키는 헤더가 **그려진** 순서로 꽂히고,
    // lazy 목록에서 그 순서는 날짜순이 아니다. 그래서 둘 다 거리로 고른다.
    final best = passed ?? upcoming;
    if (best == null || best == _reportedVisibleDate) return;
    _reportedVisibleDate = best;
    notify(best);
  }

  /// 과거 페이지를 받아 목록 앞에 붙이되, 사용자가 보던 위치를 유지한다.
  ///
  /// 위에 항목이 끼어들면 그만큼 콘텐츠가 아래로 밀려, 보고 있던 카드가 화면
  /// 밖으로 튀어나간다. 붙이기 전후의 maxScrollExtent 차이가 곧 늘어난 높이라,
  /// 그만큼 오프셋을 더해 주면 화면에 보이는 내용은 그대로 남는다.
  Future<void> _loadPreviousKeepingOffset() async {
    if (!_viewModel.hasPrev || _viewModel.loadingPrevious) return;
    final before =
        _scrollController.hasClients
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    // notify 유실(화면 재생성 중 VM dispose 등)에 대비해 build 후에도 스크롤을
    // 재시도한다. _scrolledForVersion 가드로 같은 조회 결과에 대한 실행은 한 번뿐이다.
    if (_scrolledForVersion != _viewModel.scheduleVersion) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeInitialScroll(),
      );
    }

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildList(context, scale),
    );
  }

  Widget _buildList(BuildContext context, double scale) {
    final items = _flatten(_viewModel.schedule);
    final loading = _viewModel.loadingMatches || _viewModel.loadingMore;
    final bottomPadding = widget.listBottomPadding * scale;

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
          padding: EdgeInsets.only(bottom: bottomPadding),
          itemCount: 5,
          // 첫 장은 실제 카드와 같이 위 구분선을 끈다(날짜 헤더 아래 첫 카드 규칙).
          itemBuilder:
              (_, index) =>
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
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) return _buildFooter(scale);
        final item = items[index];
        if (item is _AdItem) {
          return CheerAdBanner(
            placement: 'match_list',
            key: ValueKey('ad-${item.date}'),
            scale: scale,
            topPadding: 16,
            bottomPadding: 16,
            horizontalPadding: 8,
          );
        }
        if (item is _HeaderItem) {
          // 날짜마다 **자기 키 하나**를 갖는다. 지금 화면 맨 위에 걸린
          // 날짜를 재서 캘린더에 알리는 데 쓴다([_reportVisibleDate]).
          //
          // 자동 스크롤 대상([_todayHeaderKey])을 이 맵에 겹쳐 넣으면 안
          // 된다 — 대상이 바뀌면 옛 날짜와 새 날짜가 같은 GlobalKey 를
          // 가리키게 되고, GlobalKey 는 한 위젯에만 붙으므로 위치를 재면
          // 엉뚱한 날짜가 나온다. 대상 헤더는 아래에서 한 겹 더 감싼다.
          final key = _headerKeys[item.date] ??= GlobalKey();
          final isTarget =
              _targetDate != null && _isSameDate(item.date, _targetDate!);
          return KeyedSubtree(
            key: key,
            child: isTarget
                ? KeyedSubtree(key: _todayHeaderKey, child: _dateHeader(item, scale))
                : _dateHeader(item, scale),
          );
        }
        if (item is _LeagueHeaderItem) {
          return MatchLeagueHeader(leagueName: item.leagueName, scale: scale);
        }
        final card = item as _CardItem;
        final m = card.match;
        // 날짜 헤더·리그 헤더 바로 아래(=화면상 첫 카드)면 위 구분선을 끈다.
        final neighborIndex = index - 1;
        final showTopBorder =
            !(neighborIndex >= 0 &&
                neighborIndex < items.length &&
                (items[neighborIndex] is _HeaderItem ||
                    items[neighborIndex] is _LeagueHeaderItem));
        return MatchCard(
          key: ValueKey('match-${m.matchId}'),
          matchId: m.matchId,
          spoilerRevealed: _revealedMatchIds.contains(m.matchId),
          onSpoilerReveal:
              () => setState(() => _revealedMatchIds.add(m.matchId)),
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
          liveSetLabel:
              _isLive(m.matchStatus)
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
          onTap: () => _openMatchDetail(m, card.position),
          scale: scale,
        );
      },
    );
  }

  /// 날짜 그룹 헤더 한 줄.
  Widget _dateHeader(_HeaderItem item, double scale) => Padding(
    // 날짜 헤더와 바로 아래 리그 헤더/카드 사이 갭.
    padding: EdgeInsets.only(bottom: 8 * scale),
    child: MatchDateHeader(
      isToday: _isToday(item.date),
      dateText: _formatDate(context, item.date),
      todayLabel: AppLocalizations.of(context)!.today,
      scale: scale,
    ),
  );

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

  /// [_flatten] 결과 캐시와, 그 계산이 딛고 있던 목록 상태.
  ///
  /// 평탄화 결과는 목록 내용이 그대로면 매번 같다. 그런데 [_buildList] 는
  /// [ListenableBuilder] 안이라 VM 이 알릴 때마다 다시 도는데, 로딩 플래그
  /// 하나가 바뀌었을 뿐인 알림(prefetch 페이지마다 여러 번)에도 목록 전체를
  /// 새로 펴고 있었다. 목록이 실제로 변했을 때만 다시 편다.
  List<_ListItem>? _cachedFlattened;
  int? _cachedFlattenedLength;
  int? _cachedFlattenedVersion;
  bool? _cachedFlattenedGroupByLeague;

  /// 날짜 그룹을 헤더+카드 1차원 목록으로 편다.
  /// 담긴 순서가 곧 화면 순서라(서버 sort) 헤더는 항상 그 날짜 카드들 앞에 온다.
  ///
  /// 리그 필터가 '전체'면 여러 리그 경기가 날짜별로 섞여 오므로, 같은 날짜
  /// 안에서 리그별로 다시 묶어(첫 등장 순서 유지) 그 앞에 리그 헤더를 낀다.
  /// 특정 리그를 골랐으면 그 날 경기가 전부 한 리그라 헤더가 무의미해 생략한다.
  List<_ListItem> _flatten(List<ScheduleDay> schedule) {
    final groupByLeague =
        _viewModel.selectedLeague == MatchListViewModel.allLeagueLabel;
    // 페이지가 앞뒤로 붙으면 그룹 수가 변한다. 길이·조회 버전·그룹핑 방식이
    // 모두 그대로면 펴 놓은 결과도 그대로다.
    final cached = _cachedFlattened;
    if (cached != null &&
        _cachedFlattenedLength == schedule.length &&
        _cachedFlattenedVersion == _viewModel.scheduleVersion &&
        _cachedFlattenedGroupByLeague == groupByLeague) {
      return cached;
    }
    final out = <_ListItem>[];
    var cardPosition = 0;
    for (var i = 0; i < schedule.length; i++) {
      final day = schedule[i];
      if (_adBefore(i)) out.add(_AdItem(day.date));
      out.add(_HeaderItem(day.date));
      if (!groupByLeague) {
        for (final m in day.matches) {
          out.add(_CardItem(m, ++cardPosition));
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
          out.add(_CardItem(m, ++cardPosition));
        }
      }
    }
    // 목록이 실제로 변한 시점 = 죽은 키가 생겼을 수 있는 시점.
    _pruneHeaderKeys();
    _cachedFlattened = out;
    _cachedFlattenedLength = schedule.length;
    _cachedFlattenedVersion = _viewModel.scheduleVersion;
    _cachedFlattenedGroupByLeague = groupByLeague;
    return out;
  }

  /// [index] 번째 날짜 그룹 앞에 광고를 낄지. 세 번째 그룹 앞(2)에 하나, 그다음은
  /// 8그룹마다 하나다. 목록 맨 앞부터 세므로 어떤 필터에서도 첫 화면 가까이에
  /// 첫 광고가 오고 간격이 일정하다. 그룹 경계에만 끼워 카드 구분선 규칙을
  /// 건드리지 않는다.
  ///
  /// 과거 페이지가 앞에 붙으면 번호가 밀려 광고 자리가 한 번 옮겨 간다.
  ///
  /// [_estimatedOffsetTo] 는 광고 높이를 더하지 않는다 — 광고는 로드돼야 높이가
  /// 생기고 안 로드되면 0 이라, 어림값이 실제보다 작게 나오는 쪽이 안전하다
  /// (크게 나오면 대상이 화면 위로 지나쳐 스크롤이 거꾸로 못 간다).
  static bool _adBefore(int index) => index % 8 == 2;

  String _shortName(MatchTeam team) =>
      team.teamCode.isNotEmpty ? team.teamCode : team.teamName;

  /// 라이브 판정은 표기 흔들림(`inProgress` 등)을 흡수하는 공용 유틸에 맡긴다.
  bool _isLive(String status) => isLiveMatchStatus(status);

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d == today;
  }

  String _formatDate(BuildContext context, DateTime d) =>
      AppLocalizations.of(context)!.yearMonthDay(d.year, d.month, d.day);

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

/// 날짜 그룹 사이 배너 자리. [date] 는 바로 뒤따르는 날짜 헤더의 날짜로,
/// 과거 페이지가 앞에 붙어도 같은 광고가 같은 자리에 남도록 키로 쓴다.
class _AdItem extends _ListItem {
  const _AdItem(this.date);
  final DateTime date;
}

class _CardItem extends _ListItem {
  const _CardItem(this.match, this.position);
  final ScheduleMatch match;

  /// 화면에 보이는 전체 카드 순번(1부터). 날짜·리그 그룹과 무관하게 센다 —
  /// 클릭이 목록 위쪽에 몰리는지 보려는 값이라 그룹마다 1 로 돌아가면 안 된다.
  final int position;
}
