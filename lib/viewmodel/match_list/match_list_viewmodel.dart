import 'package:flutter/foundation.dart';

import '../../model/category_tree.dart';
import '../../model/schedule_match.dart';
import '../../repository/category/category_repository.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 경기 리스트 화면의 상태·로직.
class MatchListViewModel extends ChangeNotifier {
  MatchListViewModel({
    CategoryRepository? categoryRepository,
    ScheduleRepository? scheduleRepository,
  }) : _categoryRepository = categoryRepository ?? CategoryRepository.instance,
       _scheduleRepository =
           scheduleRepository ?? ScheduleRepository.instance {
    _loadLeagues();
  }

  final CategoryRepository _categoryRepository;
  final ScheduleRepository _scheduleRepository;

  /// 팀 멀티 셀렉트의 '전체' 가상 옵션 라벨. 단독 선택을 의미한다.
  static const String allTeamsLabel = '전체';

  /// 화면 진입 시 우선 선택할 리그 이름. 옵션에 없으면 첫 항목으로 fallback.
  static const String defaultLeague = 'LCK';

  /// 커서 페이지 한 번에 받는 경기 수.
  static const int _pageSize = 20;

  /// 한 번의 reload/loadMore 호출에서 최소로 모아야 하는 매치 수.
  /// 클라 팀 필터 결과가 적어 화면이 안 차고 스크롤이 안 트리거되는 걸 방지한다.
  static const int _minMatchesPerLoad = 5;

  /// 자동 prefetch 최대 시도 횟수. 결과가 적을 때 추가 페이지를 커서로 더 받는다.
  static const int _maxPrefetchPages = 5;

  /// 선택 가능한 시즌 목록.
  static const List<String> seasons = ['2025', '2026'];

  /// 정렬 순서 옵션. fetch 방향은 항상 최신→과거이고, '오래된 순' 은
  /// 누적된 결과만 클라이언트에서 뒤집어 보여준다.
  static const List<String> sortOrders = ['최근순', '오래된 순'];

  String _sortOrder = sortOrders.first;
  String get sortOrder => _sortOrder;

  void selectSortOrder(String order) {
    if (_sortOrder == order) return;
    _sortOrder = order;
    notifyListeners();
  }

  /// 현재 선택된 시즌. 기본값은 가장 최근 시즌.
  String _selectedSeason = seasons.last;
  String get selectedSeason => _selectedSeason;

  /// 마지막으로 받아온 카테고리 트리. 리그 변경 시 재요청 없이 팀을 갱신한다.
  CategoryTree? _tree;

  List<String> _leagues = const [];
  List<String> get leagues => _leagues;

  String? _selectedLeague;
  String? get selectedLeague => _selectedLeague;

  bool _loadingLeagues = false;
  bool get loadingLeagues => _loadingLeagues;

  List<String> _teams = const [allTeamsLabel];
  List<String> get teams => _teams;

  Set<String> _selectedTeams = {allTeamsLabel};
  Set<String> get selectedTeams => _selectedTeams;

  /// 무한 스크롤로 누적된 날짜별 경기 그룹. 내부는 항상 최신→과거 순.
  final List<ScheduleDay> _schedule = [];

  /// [_sortOrder] 에 따라 정렬한 결과. '오래된 순' 이면 역순.
  List<ScheduleDay> get schedule => List.unmodifiable(
    _sortOrder == sortOrders[1] ? _schedule.reversed : _schedule,
  );

  /// 다음 페이지 커서. 첫 페이지는 null (커서 생략).
  String? _cursor;

  /// 더 받을 페이지가 있는지. 서버 응답의 `hasNext` 로 갱신한다.
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _loadingMatches = false;
  bool get loadingMatches => _loadingMatches;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  void selectSeason(String season) {
    if (_selectedSeason == season) return;
    _selectedSeason = season;
    notifyListeners();
    _loadLeagues();
  }

  void selectLeague(String league) {
    if (_selectedLeague == league) return;
    _selectedLeague = league;
    _updateTeams();
    notifyListeners();
    _reloadSchedule();
  }

  void updateSelectedTeams(Set<String> next) {
    final wasAll = _selectedTeams.contains(allTeamsLabel);
    final hasAll = next.contains(allTeamsLabel);
    Set<String> result;
    if (next.isEmpty) {
      result = {allTeamsLabel};
    } else if (hasAll && !wasAll) {
      result = {allTeamsLabel};
    } else if (hasAll && next.length > 1) {
      result = next.where((t) => t != allTeamsLabel).toSet();
    } else {
      result = next;
    }
    if (setEquals(_selectedTeams, result)) return;
    _selectedTeams = result;
    notifyListeners();
    _reloadSchedule();
  }

  /// 무한 스크롤이 끝에 도달했을 때 호출. 커서로 다음 페이지를 가져온다.
  /// 클라 팀 필터 결과가 [_minMatchesPerLoad] 미만이면 자동으로 다음 페이지까지 prefetch.
  Future<void> loadMoreMatches() async {
    if (_loadingMatches || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    _notify();
    try {
      var newMatches = 0;
      var attempts = 0;
      while (_hasMore &&
          newMatches < _minMatchesPerLoad &&
          attempts < _maxPrefetchPages) {
        newMatches += await _fetchNextPage();
        attempts++;
        _notify(); // 매 페이지마다 즉시 반영해 점진 표시.
      }
    } catch (_) {
      // 추가 로드 실패는 무한 스크롤 흐름을 막지 않기 위해 무시.
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  Future<void> _loadLeagues() async {
    _loadingLeagues = true;
    _notify();
    try {
      final year = int.parse(_selectedSeason);
      // 리그 목록은 경기일정 페이지와 동일하게 필터 옵션(ALLOWED_LEAGUES)에서 받는다.
      final options = await _scheduleRepository.fetchFilterOptions();
      _leagues = options.leagues.map((l) => l.name).toList();
      // 팀 목록은 연도별 카테고리 트리에서 받는다.
      _tree = await _categoryRepository.fetchTree(year: year);
      if (_leagues.isEmpty) {
        _selectedLeague = null;
      } else if (_selectedLeague == null ||
          !_leagues.contains(_selectedLeague)) {
        _selectedLeague = _leagues.contains(defaultLeague)
            ? defaultLeague
            : _leagues.first;
      }
      _updateTeams();
    } catch (_) {
      _tree = null;
      _leagues = const [];
      _selectedLeague = null;
      _teams = const [allTeamsLabel];
      _selectedTeams = {allTeamsLabel};
    } finally {
      _loadingLeagues = false;
      _notify();
    }
    await _reloadSchedule();
  }

  void _updateTeams() {
    final tree = _tree;
    final league = _selectedLeague;
    if (tree == null || league == null) {
      _teams = const [allTeamsLabel];
      _selectedTeams = {allTeamsLabel};
      return;
    }
    final year = int.parse(_selectedSeason);
    final season = tree.seasons.firstWhere(
      (s) => s.year == year,
      orElse: () => tree.seasons.isNotEmpty
          ? tree.seasons.first
          : const CategorySeason(year: 0, leagues: []),
    );
    final leagueData = season.leagues.firstWhere(
      (l) => l.name == league,
      orElse: () => const CategoryLeague(name: '', splits: []),
    );
    final seen = <int>{};
    final names = <String>[];
    for (final split in leagueData.splits) {
      for (final team in split.teams) {
        if (seen.add(team.id)) {
          names.add(team.name);
        }
      }
    }
    _teams = [allTeamsLabel, ...names];
    _selectedTeams = {allTeamsLabel};
  }

  /// 필터(시즌/리그/팀) 변경 시 커서를 초기화하고 첫 페이지부터 다시 받는다.
  /// 첫 페이지를 받자마자 카드를 보여주고, 부족하면 자동 prefetch 로 더 채운다.
  Future<void> _reloadSchedule() async {
    _loadingMatches = true;
    _schedule.clear();
    _cursor = null;
    _hasMore = true;
    _notify();
    try {
      // 1) 첫 페이지 — spinner 가린 채로.
      var newMatches = await _fetchNextPage();
      _loadingMatches = false;
      _notify();

      // 2) 부족하면 prefetch — loadingMore 인디케이터로 점진 표시.
      if (newMatches < _minMatchesPerLoad && _hasMore) {
        _loadingMore = true;
        _notify();
        var attempts = 1;
        while (_hasMore &&
            newMatches < _minMatchesPerLoad &&
            attempts < _maxPrefetchPages) {
          newMatches += await _fetchNextPage();
          attempts++;
          _notify();
        }
        _loadingMore = false;
        _notify();
      }
    } catch (_) {
      _hasMore = false;
      _loadingMatches = false;
      _loadingMore = false;
      _notify();
    }
  }

  /// 현재 커서로 한 페이지를 받아 [_schedule] 에 날짜별로 누적한다.
  /// 커서·hasNext 를 갱신하고, 누적된(필터 통과) 매치 수를 반환한다.
  Future<int> _fetchNextPage() async {
    final league = _selectedLeague;
    final page = await _scheduleRepository.fetchMatches(
      cursor: _cursor,
      size: _pageSize,
      league: (league != null && league.isNotEmpty) ? league : defaultLeague,
      seasonYear: int.tryParse(_selectedSeason),
    );
    _cursor = page.nextCursor;
    _hasMore = page.hasNext && page.nextCursor != null;
    final filtered = _applyFilters(page.matches);
    _mergeIntoSchedule(filtered);
    return filtered.length;
  }

  /// 새 페이지 매치(최신→과거 순)를 날짜별 그룹으로 묶어 [_schedule] 뒤에 붙인다.
  /// 페이지 경계에서 같은 날짜가 걸치면 마지막 기존 그룹에 머지한다.
  void _mergeIntoSchedule(List<ScheduleMatch> matches) {
    final groups = _groupByDate(matches);
    if (groups.isEmpty) return;
    if (_schedule.isNotEmpty &&
        _isSameDate(_schedule.last.date, groups.first.date)) {
      final last = _schedule.removeLast();
      _schedule.add(ScheduleDay(
        date: last.date,
        matches: [...last.matches, ...groups.first.matches],
      ));
      _schedule.addAll(groups.skip(1));
    } else {
      _schedule.addAll(groups);
    }
  }

  /// 매치 목록(최신→과거 순)을 같은 날짜끼리 [ScheduleDay] 로 묶는다. 순서 보존.
  /// `date` 가 null 인 매치는 직전 그룹에 합쳐(없으면 epoch 날짜로) 표시한다.
  List<ScheduleDay> _groupByDate(List<ScheduleMatch> matches) {
    final out = <ScheduleDay>[];
    DateTime? currentDate;
    var current = <ScheduleMatch>[];
    void flush() {
      if (current.isNotEmpty) {
        out.add(ScheduleDay(
          date: currentDate ?? DateTime.fromMillisecondsSinceEpoch(0),
          matches: current,
        ));
      }
    }

    for (final m in matches) {
      final d = m.date;
      if (current.isEmpty || _isSameDate(currentDate, d)) {
        currentDate ??= d;
        current.add(m);
      } else {
        flush();
        currentDate = d;
        current = [m];
      }
    }
    flush();
    return out;
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 클라이언트 팀 필터: teamA/teamB.teamName. 리그는 서버 파라미터로 거른다
  /// (안전망으로 leagueInfo 도 확인).
  List<ScheduleMatch> _applyFilters(List<ScheduleMatch> matches) {
    final league = _selectedLeague;
    final allTeams = _selectedTeams.contains(allTeamsLabel);
    return matches.where((m) {
      if (league != null &&
          league.isNotEmpty &&
          m.leagueInfo.isNotEmpty &&
          m.leagueInfo != league) {
        return false;
      }
      if (!allTeams) {
        final inSelected = _selectedTeams.contains(m.teamA.teamName) ||
            _selectedTeams.contains(m.teamB.teamName);
        if (!inSelected) return false;
      }
      return true;
    }).toList();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }
}

/// 날짜 + 해당 날짜 경기 목록 묶음. 화면에서 헤더 + 카드 그룹으로 렌더링.
class ScheduleDay {
  const ScheduleDay({required this.date, required this.matches});
  final DateTime date;
  final List<ScheduleMatch> matches;
}
