import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/category_tree.dart';
import '../../model/schedule_match.dart';
import '../../repository/category/category_repository.dart';
import '../../repository/preference/filter_preference_repository.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 경기 리스트 화면의 상태·로직.
class MatchListViewModel extends ChangeNotifier {
  MatchListViewModel({
    CategoryRepository? categoryRepository,
    ScheduleRepository? scheduleRepository,
    FilterPreferenceRepository? filterPreferences,
  }) : _categoryRepository = categoryRepository ?? CategoryRepository.instance,
       _scheduleRepository =
           scheduleRepository ?? ScheduleRepository.instance,
       _filterPreferences =
           filterPreferences ?? FilterPreferenceRepository.instance {
    _init();
  }

  final CategoryRepository _categoryRepository;
  final ScheduleRepository _scheduleRepository;
  final FilterPreferenceRepository _filterPreferences;

  /// 복원됐지만 아직 리그 목록 검증 전인 팀 선택. [_updateTeams] 가 1회 소비한다.
  Set<String>? _pendingRestoredTeams;

  /// 마지막 사용 필터(시즌/리그/팀)를 복원한 뒤 리그 목록을 불러온다.
  /// 리그는 [_loadLeagues] 가 서버 목록과 대조해 없으면 '전체'로 되돌리고,
  /// 팀은 [_updateTeams] 가 현재 리그 팀 목록과 교집합만 살린다.
  Future<void> _init() async {
    final saved =
        await _filterPreferences.load(FilterPreferenceRepository.matchListKey);
    if (saved != null) {
      final season = saved['season'] as String?;
      if (season != null && seasons.contains(season)) {
        _selectedSeason = season;
      }
      final league = saved['league'] as String?;
      if (league != null && league.isNotEmpty) {
        _selectedLeague = league;
      }
      final teams = (saved['teams'] as List?)?.cast<String>();
      if (teams != null && teams.isNotEmpty) {
        _pendingRestoredTeams = teams.toSet();
      }
      // 라벨은 언어에 따라 바뀌므로 인덱스로 저장·복원한다. 저장 당시보다
      // 옵션이 줄어든 버전에서도 안전하도록 범위를 확인한다.
      final sortOrder = saved['sortOrder'] as int?;
      if (sortOrder != null && sortOrder >= 0 && sortOrder < _sortOrderCount) {
        _sortOrderIndex = sortOrder;
      }
    }
    await _loadLeagues();
  }

  /// 현재 필터를 저장한다. 실패해도 조회는 계속되므로 기다리지 않는다.
  void _persistFilter() {
    unawaited(_filterPreferences.save(FilterPreferenceRepository.matchListKey, {
      'season': _selectedSeason,
      'league': _selectedLeague,
      'teams': _selectedTeams.toList(),
      'sortOrder': _sortOrderIndex,
    }));
  }

  /// 팀 멀티 셀렉트의 '전체' 가상 옵션 라벨. 단독 선택을 의미한다.
  /// 내부 비교 키로도 쓰이므로 static const 로 고정한다.
  static const String allTeamsLabel = '전체';

  /// 리그 필터의 '전체' 가상 옵션 라벨. 화면 진입 시 기본 선택된다.
  /// 내부 비교 키로도 쓰이므로 static const 로 고정한다.
  static const String allLeagueLabel = '전체';

  /// '전체' 리그로 조회할 때 서버에 보낼 리그 코드.
  static const String allLeagueCode = 'ALL';

  /// 커서 페이지 한 번에 받는 경기 수.
  static const int _pageSize = 20;

  /// 한 번의 reload/loadMore 호출에서 최소로 모아야 하는 매치 수.
  /// 클라 팀 필터 결과가 적어 화면이 안 차고 스크롤이 안 트리거되는 걸 방지한다.
  static const int _minMatchesPerLoad = 5;

  /// 자동 prefetch 최대 시도 횟수. 결과가 적을 때 추가 페이지를 커서로 더 받는다.
  static const int _maxPrefetchPages = 5;

  /// 초기 진입 시 '오늘' 그룹으로 스크롤하려면 오늘 이하 경기가 최소 한 건은
  /// 로드돼 있어야 한다. '전체'(ALL) 리그는 최신 페이지가 전부 미래(예정) 경기라
  /// 오늘 이하가 나올 때까지 더 당겨야 하므로 catch-up 최대 페이지를 넉넉히 둔다.
  /// (2026-08 시점 ALL 기준 오늘까지 9페이지. 시즌 초는 예정 경기가 더 많다.)
  static const int _maxCatchUpPages = 20;

  /// 선택 가능한 시즌 목록.
  static const List<String> seasons = ['2025', '2026'];

  /// 정렬 순서 옵션. fetch 방향은 '오늘 이후'만 과거→미래고 나머지는 최신→과거다
  /// ([scheduleAscending]). 표시 방향은 View 가 [listReversed] 로 맞춘다.
  /// 기본은 '오래된 순'(위가 과거, 아래가 미래).
  /// 표시용 라벨 목록 — l10n 에서 가져온다.
  /// 순서(0=최근순, 1=오래된 순, 2=오늘 이후)는 고정.
  List<String> get sortOrders => [
        appStrings?.sortRecent ?? 'Recent',
        appStrings?.sortOldest ?? 'Oldest',
        appStrings?.sortUpcoming ?? 'Upcoming',
      ];

  /// 정렬 옵션 개수. [sortOrders] 는 l10n 을 읽어 위젯 바인딩이 필요하므로,
  /// 복원 시 범위 확인처럼 바인딩 없이 쓰는 곳은 이 상수를 본다.
  static const int _sortOrderCount = 3;

  /// 0=최근순, 1=오래된 순, 2=오늘 이후. 라벨이 언어에 따라 바뀌어도 index로 비교한다.
  int _sortOrderIndex = 1;

  String get sortOrder => sortOrders[_sortOrderIndex];

  /// 화면 위→아래가 과거→미래(시간 오름차순)인지.
  /// '오래된 순'(1)·'오늘 이후'(2) 일 때 true.
  bool get ascending => _sortOrderIndex >= 1;

  /// '오늘 이후'(index 2) — 오늘 0시 이전에 시작한 경기는 목록에서 제외한다.
  bool get upcomingOnly => _sortOrderIndex == 2;

  /// [schedule] 이 담긴 순서가 과거→미래인지.
  ///
  /// '오늘 이후'만 서버에 `from=오늘` 을 보내 오름차순으로 받으므로 true 고,
  /// 나머지 정렬은 최신→과거 순으로 담긴다.
  bool get scheduleAscending => upcomingOnly;

  /// View 가 리스트를 뒤집어 그려야 하는지(`ListView.reverse`).
  ///
  /// 화면은 [ascending] 이 원하는 방향으로 보여야 하는데, 저장 순서가 이미
  /// 그 방향([scheduleAscending])이면 뒤집을 필요가 없다.
  bool get listReversed => ascending && !scheduleAscending;

  void selectSortOrder(String order) {
    final idx = sortOrders.indexOf(order);
    if (idx < 0 || idx == _sortOrderIndex) return;
    final wasUpcomingOnly = upcomingOnly;
    _sortOrderIndex = idx;
    _persistFilter();
    // '오늘 이후' 를 켜고 끌 때는 필터 조건 자체가 바뀌므로 첫 페이지부터 다시 받는다.
    // (누적본에는 이미 걸러진 과거 경기가 없어 되돌릴 수 없다.)
    // _reloadSchedule 이 버전을 올리고 notify 하므로 여기선 따로 알리지 않는다.
    if (wasUpcomingOnly != upcomingOnly) {
      _reloadSchedule();
      return;
    }
    // 재조회가 필요 없는 전환(최근순↔오래된 순)도 표시 방향이 뒤집히므로
    // 버전을 올려 View 가 오늘 날짜로 다시 스크롤하게 한다.
    _scheduleVersion++;
    notifyListeners();
  }

  /// 카드 스코어 블러(스포방지) on/off. 기본 on(기존 동작 유지).
  bool _spoilerPreventionEnabled = true;
  bool get spoilerPreventionEnabled => _spoilerPreventionEnabled;

  void setSpoilerPreventionEnabled(bool value) {
    if (_spoilerPreventionEnabled == value) return;
    _spoilerPreventionEnabled = value;
    notifyListeners();
  }

  /// 현재 선택된 시즌. 기본값은 가장 최근 시즌.
  String _selectedSeason = seasons.last;
  String get selectedSeason => _selectedSeason;

  /// 마지막으로 받아온 카테고리 트리. 리그 변경 시 재요청 없이 팀을 갱신한다.
  CategoryTree? _tree;

  List<String> _leagues = const [allLeagueLabel];
  List<String> get leagues => _leagues;

  String? _selectedLeague = allLeagueLabel;
  String? get selectedLeague => _selectedLeague;

  bool _loadingLeagues = false;
  bool get loadingLeagues => _loadingLeagues;

  List<String> _teams = const [allTeamsLabel];
  List<String> get teams => _teams;

  Set<String> _selectedTeams = {allTeamsLabel};
  Set<String> get selectedTeams => _selectedTeams;

  /// 무한 스크롤로 누적된 날짜별 경기 그룹. 담긴 순서는 서버 응답 방향과 같다.
  final List<ScheduleDay> _schedule = [];

  /// 담긴 순서는 [scheduleAscending] 이 알려준다 — '오늘 이후'는 과거→미래,
  /// 나머지는 최신→과거. 어느 쪽이든 다음 페이지가 뒤에 append 되므로 스크롤
  /// 점프가 없다. 표시 방향은 View 가 [listReversed] 로 맞춘다.
  List<ScheduleDay> get schedule => List.unmodifiable(_schedule);

  /// 다음 페이지 커서. 첫 페이지는 null (커서 생략).
  String? _cursor;

  /// 더 받을 페이지가 있는지. 서버 응답의 `hasNext` 로 갱신한다.
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _loadingMatches = false;
  bool get loadingMatches => _loadingMatches;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  /// [_reloadSchedule] 이 새로 시작할 때마다 증가. View 는 이 값이 바뀔 때마다
  /// '오늘로 스크롤'을 다시 수행해, 필터 변경으로 재조회될 때도 오늘 날짜로 이동한다.
  int _scheduleVersion = 0;
  int get scheduleVersion => _scheduleVersion;

  void selectSeason(String season) {
    if (_selectedSeason == season) return;
    _selectedSeason = season;
    _persistFilter();
    notifyListeners();
    _loadLeagues();
  }

  void selectLeague(String league) {
    if (_selectedLeague == league) return;
    _selectedLeague = league;
    _updateTeams();
    _persistFilter();
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
    _persistFilter();
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
      final tree = await _categoryRepository.fetchTree(year: year);
      _tree = tree;
      // 리그 목록은 경기일정 필터와 동일 소스(메이저 큐레이션, MSI 포함)로 통일한다.
      // 카테고리 트리는 연도 스코프라 MSI 등 단기 대회가 누락되므로 팀 목록 산출 용도로만 유지한다.
      final options = await _scheduleRepository.fetchFilterOptions();
      // 서버가 이미 맨 앞에 '전체'(code ALL) 옵션을 포함해 내려준다.
      _leagues = options.leagues.map((l) => l.name).toList();
      if (_selectedLeague == null || !_leagues.contains(_selectedLeague)) {
        _selectedLeague = _leagues.contains(allLeagueLabel)
            ? allLeagueLabel // 기본 '전체'.
            : (_leagues.isNotEmpty ? _leagues.first : null);
      }
      _updateTeams();
    } catch (_) {
      // 옵션 로드 실패 시에도 '전체'(ALL)로는 조회할 수 있게 유지한다.
      _tree = null;
      _leagues = const [allLeagueLabel];
      _selectedLeague = allLeagueLabel;
      _teams = const [allTeamsLabel];
      _selectedTeams = {allTeamsLabel};
    } finally {
      _loadingLeagues = false;
      _notify();
    }
    await _reloadSchedule();
  }

  void _updateTeams() {
    // 앱 재시작 복원분은 1회만 소비한다. 리그가 '전체'라 팀 스코프가 없으면 버린다.
    final pendingRestored = _pendingRestoredTeams;
    _pendingRestoredTeams = null;

    final tree = _tree;
    final league = _selectedLeague;
    // '전체'(ALL) 리그는 특정 리그 팀 스코프가 없어 팀 필터를 '전체'만 둔다.
    if (tree == null || league == null || league == allLeagueLabel) {
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

    // 복원된 팀 선택 중 현재 리그 팀 목록에 남아 있는 것만 되살린다.
    // (시즌이 바뀌어 팀이 사라졌으면 자연스럽게 '전체'로 남는다.)
    if (pendingRestored != null) {
      final valid = pendingRestored.where(_teams.contains).toSet();
      if (valid.isNotEmpty) _selectedTeams = valid;
    }
  }

  /// 필터(시즌/리그/팀) 변경 시 커서를 초기화하고 첫 페이지부터 다시 받는다.
  /// 첫 페이지를 받자마자 카드를 보여주고, 부족하면 자동 prefetch 로 더 채운다.
  Future<void> _reloadSchedule() async {
    _scheduleVersion++;
    _loadingMatches = true;
    _schedule.clear();
    _cursor = null;
    _hasMore = true;
    _notify();
    try {
      // 1) 첫 페이지.
      var newMatches = await _fetchNextPage();

      // 2) prefetch 필요 판단 — 화면이 안 찰 만큼 결과가 적거나(_minMatchesPerLoad
      //    미만), 초기 '오늘로 스크롤' 대상인 오늘 이하 경기가 아직 안 왔으면
      //    ('전체'는 최신 페이지가 전부 미래 예정 경기) 계속 당겨온다.
      //    '오늘 이후'는 서버에 from=오늘 을 보내 첫 페이지가 곧 오늘부터라,
      //    오늘 이하 조건은 보지 않는다(화면 채우기 조건만 남는다).
      final needPrefetch =
          (newMatches < _minMatchesPerLoad ||
              (!upcomingOnly && !_hasTodayOrPastLoaded())) &&
          _hasMore;

      // 첫 페이지는 즉시 노출하되, prefetch 가 필요하면 loadingMore 를 같은 프레임에
      // 켜서 View 의 초기 '오늘로 스크롤' 이 prefetch(오늘 데이터 도착)까지 기다리게 한다.
      _loadingMatches = false;
      _loadingMore = needPrefetch;
      _notify();

      if (needPrefetch) {
        var attempts = 1;
        while (_hasMore &&
            attempts < _maxCatchUpPages &&
            (newMatches < _minMatchesPerLoad ||
                (!upcomingOnly && !_hasTodayOrPastLoaded()))) {
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
    // '전체' 선택(또는 미선택)이면 서버에 'ALL' 을 보내 모든 리그를 조회한다.
    final leagueParam =
        (league == null || league.isEmpty || league == allLeagueLabel)
        ? allLeagueCode
        : league;
    final page = await _scheduleRepository.fetchMatches(
      cursor: _cursor,
      size: _pageSize,
      league: leagueParam,
      seasonYear: int.tryParse(_selectedSeason),
      // '오늘 이후' 는 서버가 오늘부터 과거→미래 오름차순으로 내려준다.
      // 다른 정렬은 from 없이 최신→과거 순 그대로 받는다.
      from: upcomingOnly ? _todayParam() : null,
    );
    _cursor = page.nextCursor;
    _hasMore = page.hasNext && page.nextCursor != null;
    final filtered = _applyFilters(page.matches);
    _mergeIntoSchedule(filtered);
    return filtered.length;
  }

  /// 서버 `from` 파라미터에 쓸 오늘 날짜(`yyyy-MM-dd`).
  String _todayParam() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// 새 페이지 매치를 날짜별 그룹으로 묶어 [_schedule] 뒤에 붙인다.
  /// 페이지가 진행하는 방향은 정렬에 따라 다르지만([scheduleAscending]),
  /// 어느 쪽이든 뒤 페이지가 앞 페이지의 연장이라 append 로 이어붙으면 된다.
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

  /// [_schedule] 에 오늘(이하) 날짜 경기가 하나라도 로드됐는지.
  /// 초기 '오늘로 스크롤' 이 동작하려면 이 조건이 참이어야 한다.
  /// (schedule 은 최신→과거 순이라 마지막 그룹이 오늘 이하면 참.)
  bool _hasTodayOrPastLoaded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final day in _schedule) {
      final d = DateTime(day.date.year, day.date.month, day.date.day);
      if (!d.isAfter(today)) return true;
    }
    return false;
  }

  /// 클라이언트 팀 필터: teamA/teamB.teamName. 리그는 서버 파라미터로 거른다
  /// (안전망으로 leagueInfo 도 확인).
  List<ScheduleMatch> _applyFilters(List<ScheduleMatch> matches) {
    final league = _selectedLeague;
    // '전체'(ALL) 는 리그로 거르지 않는다.
    final isAllLeagues =
        league == null || league.isEmpty || league == allLeagueLabel;
    final allTeams = _selectedTeams.contains(allTeamsLabel);
    // '오늘 이후' 는 오늘 0시 기준으로 그 이전 날짜 경기를 전부 뺀다.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final onlyUpcoming = upcomingOnly;
    return matches.where((m) {
      if (onlyUpcoming) {
        final d = m.date;
        if (d == null) return false;
        if (DateTime(d.year, d.month, d.day).isBefore(today)) return false;
      }
      if (!isAllLeagues &&
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
