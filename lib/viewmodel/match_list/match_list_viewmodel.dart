import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/category_tree.dart';
import '../../model/schedule_match.dart';
import '../../repository/category/category_repository.dart';
import '../../repository/preference/filter_preference_repository.dart';
import '../../repository/preference/spoiler_preference_repository.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 경기 리스트 화면의 상태·로직.
class MatchListViewModel extends ChangeNotifier {
  MatchListViewModel({
    CategoryRepository? categoryRepository,
    ScheduleRepository? scheduleRepository,
    FilterPreferenceRepository? filterPreferences,
    SpoilerPreferenceRepository? spoilerPreferences,
  }) : _categoryRepository = categoryRepository ?? CategoryRepository.instance,
       _scheduleRepository =
           scheduleRepository ?? ScheduleRepository.instance,
       _filterPreferences =
           filterPreferences ?? FilterPreferenceRepository.instance,
       _spoilerPreferences =
           spoilerPreferences ?? SpoilerPreferenceRepository.instance {
    // 이미 읽어둔 값이 있으면 첫 프레임부터 그 상태로 그린다.
    _spoilerPreventionEnabled = _spoilerPreferences.cachedValue ?? true;
    _init();
  }

  final CategoryRepository _categoryRepository;
  final ScheduleRepository _scheduleRepository;
  final FilterPreferenceRepository _filterPreferences;
  final SpoilerPreferenceRepository _spoilerPreferences;

  /// 복원됐지만 아직 리그 목록 검증 전인 팀 선택. [_updateTeams] 가 1회 소비한다.
  Set<String>? _pendingRestoredTeams;

  /// 마지막 사용 필터(시즌/리그/팀)를 복원한 뒤 리그 목록을 불러온다.
  /// 리그는 [_loadLeagues] 가 서버 목록과 대조해 없으면 '전체'로 되돌리고,
  /// 팀은 [_updateTeams] 가 현재 리그 팀 목록과 교집합만 살린다.
  Future<void> _init() async {
    await _restoreSpoilerPreference();
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
    // 리그 목록(카테고리 트리 + 필터 옵션)과 경기 리스트 조회는 서로 다른
    // API라 순서대로 기다릴 필요가 없다. 리그 선택은 이미 위에서 정해졌으니
    // (복원값 또는 기본 '전체') 리그 목록 응답을 기다리지 않고 동시에 돈다.
    // fetchTree 가 로그도 없이 0.9~2.7초씩 걸려(2026-08-12 실측) 순차로 두면
    // 경기 리스트가 그 시간만큼 이유 없이 늦게 떴었다.
    final leaguesDone = _loadLeagues(reloadAfter: false);
    await _reloadSchedule();
    await leaguesDone;
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
  ///
  /// 서버가 실제로 내려주는 상한이 50이다(그 이상 요청해도 50으로 잘림,
  /// 2026-08-12 실측). '전체' 리그는 오늘까지 캐치업하는 데 페이지가 여러 장
  /// 필요한데, 커서 체인이라 병렬화가 안 돼 페이지 수만큼 순차 왕복이
  /// 그대로 로딩 시간이 된다. 서버 상한까지 크게 받아 왕복 횟수를 줄인다
  /// (20 기준 9왕복 → 50 기준 4왕복, 2026-08 ALL 실측).
  static const int _pageSize = 50;

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

  /// 정렬 순서 옵션 라벨 — l10n 에서 가져온다.
  /// 순서(0=최근순, 1=오래된 순, 2=오늘 이후)는 고정이고 기본은 '오래된 순'.
  /// 방향은 서버가 `sort` 로 처리하므로 받은 순서가 곧 화면 순서다.
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
  /// 서버에 `sort` 를 보내 정렬 방향을 맡기므로 요청한 방향대로 담긴다.
  /// 담긴 순서가 곧 화면 순서라 View 가 뒤집을 일이 없다.
  bool get scheduleAscending => ascending;

  void selectSortOrder(String order) {
    final idx = sortOrders.indexOf(order);
    if (idx < 0 || idx == _sortOrderIndex) return;
    _sortOrderIndex = idx;
    _persistFilter();
    // 정렬은 서버가 처리한다(sort=ASC/DESC). 방향이 바뀌면 커서를 이어 쓸 수
    // 없으므로 어느 전환이든 첫 페이지부터 다시 받는다.
    // _reloadSchedule 이 버전을 올리고 notify 하므로 여기선 따로 알리지 않는다.
    _reloadSchedule();
  }

  /// 카드 스코어 블러(스포방지) on/off. 저장된 값이 없으면 on(기존 동작 유지).
  /// 경기 일정의 날짜별 리스트와 같은 저장값을 공유한다.
  bool _spoilerPreventionEnabled = true;
  bool get spoilerPreventionEnabled => _spoilerPreventionEnabled;

  /// 저장된 스포방지 설정을 복원한다. 생성자에서 캐시로 이미 맞춘 값과 같으면 알리지 않는다.
  Future<void> _restoreSpoilerPreference() async {
    final saved = await _spoilerPreferences.load();
    if (saved == _spoilerPreventionEnabled) return;
    _spoilerPreventionEnabled = saved;
    notifyListeners();
  }

  void setSpoilerPreventionEnabled(bool value) {
    if (_spoilerPreventionEnabled == value) return;
    _spoilerPreventionEnabled = value;
    // 저장 실패해도 화면 토글은 그대로 동작하므로 기다리지 않는다.
    unawaited(_spoilerPreferences.save(value));
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

  // 생성 직후 첫 프레임(비동기 초기화가 끝나기 전)에도 로딩 중으로 보여야
  // '경기가 없어요' 빈 상태 문구가 스켈레톤보다 먼저 잠깐 보이지 않는다.
  bool _loadingLeagues = true;
  bool get loadingLeagues => _loadingLeagues;

  List<String> _teams = const [allTeamsLabel];
  List<String> get teams => _teams;

  Set<String> _selectedTeams = {allTeamsLabel};
  Set<String> get selectedTeams => _selectedTeams;

  /// 무한 스크롤로 누적된 날짜별 경기 그룹. 담긴 순서는 서버 응답 방향과 같다.
  final List<ScheduleDay> _schedule = [];

  /// 담긴 순서는 서버 `sort` 를 따르며 [scheduleAscending] 이 알려준다.
  /// 어느 방향이든 다음 페이지가 뒤에 append 되므로 스크롤 점프가 없다.
  List<ScheduleDay> get schedule => List.unmodifiable(_schedule);

  /// 다음 페이지 커서. 첫 페이지는 null (커서 생략).
  String? _cursor;

  /// 더 받을 페이지가 있는지. 서버 응답의 `hasNext` 로 갱신한다.
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  /// 과거 방향 커서. 서버가 오늘 커서를 줘서 목록 중간부터 시작했을 때만
  /// 채워진다 — 첫 페이지부터 순서대로 받은 경우엔 위쪽이 이미 다 있어 null.
  String? _prevCursor;

  /// 위쪽(과거)에 더 받을 페이지가 있는지.
  bool _hasPrev = false;
  bool get hasPrev => _hasPrev;

  bool _loadingMatches = true;
  bool get loadingMatches => _loadingMatches;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  /// 과거 페이지를 받는 중인지. [loadingMore](미래 방향)와 구분해야 위/아래를
  /// 동시에 당길 때 서로를 막지 않는다.
  bool _loadingPrevious = false;
  bool get loadingPrevious => _loadingPrevious;

  /// 마지막 [_reloadSchedule] 실패 시 에러. 성공하면 null.
  Object? _error;
  Object? get error => _error;

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

  /// [reloadAfter] 를 false 로 주면(현재 [_init] 전용) 리그 선택이 그대로
  /// 유지된 경우엔 끝에서 다시 [_reloadSchedule] 을 부르지 않는다 — 호출자가
  /// 이미 같은 유효 리그 코드로 경기 조회를 병렬로 돌리고 있다고 가정한다.
  /// 저장된 리그가 서버 목록에 없어 여기서 기본값으로 바뀐 경우(드묾)엔
  /// 그 값으로 다시 조회한다. 다른 호출자([selectSeason])는 항상 true 로
  /// 불러 기존과 동일하게 끝에서 무조건 다시 조회한다.
  Future<void> _loadLeagues({bool reloadAfter = true}) async {
    _loadingLeagues = true;
    _notify();
    final previousLeagueCode = _effectiveLeagueCode(_selectedLeague);
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
    if (!reloadAfter &&
        _effectiveLeagueCode(_selectedLeague) == previousLeagueCode) {
      return;
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
    _error = null;
    _schedule.clear();
    _cursor = null;
    _hasMore = true;
    _prevCursor = null;
    _hasPrev = false;
    _lastTodayCursor = null;
    _notify();
    try {
      // 1) 첫 페이지.
      //    오래된 순(ASC)은 시즌 첫 경기부터 내려와 오늘까지 16페이지 넘게
      //    당겨야 한다(2026-08 실측). 서버가 오늘 커서를 주면 그 페이지부터
      //    바로 받아 한 번에 오늘에 닿는다. 안 주면(미지원·오늘 경기 없음)
      //    아래 catch-up 루프가 기존대로 당긴다.
      var newMatches = await _fetchFirstPage();

      // 2) prefetch 필요 판단 — 화면이 안 찰 만큼 결과가 적거나(_minMatchesPerLoad
      //    미만), 초기 '오늘로 스크롤' 대상인 오늘 그룹이 아직 안 왔으면 계속
      //    당겨온다([_hasReachedToday] 가 담긴 방향까지 감안한다).
      //    '오늘 이후'는 서버에 from=오늘 을 보내 첫 페이지가 곧 오늘부터라
      //    그 조건은 보지 않는다(화면 채우기 조건만 남는다).
      final needPrefetch =
          (newMatches < _minMatchesPerLoad ||
              (!upcomingOnly && !_hasReachedToday())) &&
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
                (!upcomingOnly && !_hasReachedToday()))) {
          newMatches += await _fetchNextPage();
          attempts++;
          _notify();
        }
        _loadingMore = false;
        _notify();
      }
    } catch (e) {
      _hasMore = false;
      _loadingMatches = false;
      _loadingMore = false;
      _error = e;
      debugPrint('[MatchList] 경기 조회 에러: $e');
      _notify();
    }
  }

  /// 경기 조회 실패 후 '다시 시도' 버튼에서 호출한다.
  Future<void> retryLoadMatches() => _reloadSchedule();

  /// 서버에 보낼 리그 코드. '전체' 선택(또는 미선택)이면 'ALL'.
  String _effectiveLeagueCode(String? league) =>
      (league == null || league.isEmpty || league == allLeagueLabel)
          ? allLeagueCode
          : league;

  /// 현재 커서로 한 페이지를 받아 [_schedule] 에 날짜별로 누적한다.
  /// 커서·hasNext 를 갱신하고, 누적된(필터 통과) 매치 수를 반환한다.
  /// 첫 페이지를 받는다. 서버가 오늘 커서를 주면 그 페이지부터 다시 받아
  /// 오늘에 한 번에 닿는다.
  ///
  /// '오늘 이후'는 서버가 `from` 으로 오늘부터 잘라 주므로 첫 페이지가 곧
  /// 오늘이라 이 우회가 필요 없다.
  Future<int> _fetchFirstPage() async {
    final probe = await _fetchNextPage();
    final todayCursor = _lastTodayCursor;
    // 오늘 커서가 없거나(미지원), 이미 오늘이 담겼으면 그대로 쓴다.
    if (upcomingOnly || todayCursor == null || _hasReachedToday()) {
      return probe;
    }
    // 오늘 페이지부터 다시 받는다 — 지금까지 받은 앞부분은 버린다.
    _schedule.clear();
    _cursor = todayCursor;
    _hasMore = true;
    final count = await _fetchNextPage();
    return count;
  }

  /// 직전 응답이 알려준 오늘 커서. [_fetchNextPage] 가 갱신한다.
  String? _lastTodayCursor;

  Future<int> _fetchNextPage() async {
    final page = await _scheduleRepository.fetchMatches(
      cursor: _cursor,
      size: _pageSize,
      league: _effectiveLeagueCode(_selectedLeague),
      seasonYear: int.tryParse(_selectedSeason),
      // '오늘 이후' 는 오늘 이전 경기를 서버에서 잘라낸다(from).
      from: upcomingOnly ? _todayParam() : null,
      // 정렬 방향은 서버에 맡긴다 — 받은 순서 그대로 그리면 되므로 View 가
      // 뒤집을 필요가 없다.
      sort: ascending ? 'ASC' : 'DESC',
    );
    _cursor = page.nextCursor;
    _hasMore = page.hasNext && page.nextCursor != null;
    _lastTodayCursor = page.todayCursor;
    // 과거 커서는 첫 페이지 응답에만 의미가 있다(그 뒤로는 계속 미래로 가므로
    // 위쪽 경계가 그대로다). 이미 잡아둔 값이 있으면 덮어쓰지 않는다.
    if (_prevCursor == null && page.prevCursor != null) {
      _prevCursor = page.prevCursor;
      _hasPrev = page.hasPrev;
    }
    final filtered = _applyFilters(page.matches);
    _mergeIntoSchedule(filtered);
    return filtered.length;
  }

  /// 위쪽(과거) 한 페이지를 받아 목록 앞에 붙인다. 받은 개수를 반환한다.
  Future<int> _fetchPreviousPage() async {
    final page = await _scheduleRepository.fetchMatches(
      cursor: _prevCursor,
      size: _pageSize,
      league: _effectiveLeagueCode(_selectedLeague),
      seasonYear: int.tryParse(_selectedSeason),
      // 과거로 거슬러 갈 때는 from(오늘 이후)을 걸면 안 된다.
      sort: ascending ? 'ASC' : 'DESC',
      direction: 'PREV',
    );
    _prevCursor = page.prevCursor;
    _hasPrev = page.hasPrev && page.prevCursor != null;
    final filtered = _applyFilters(page.matches);
    _prependIntoSchedule(filtered);
    return filtered.length;
  }

  /// 사용자가 목록 위쪽 끝에 닿았을 때 호출. 과거 경기를 이어받는다.
  ///
  /// 서버가 오늘 커서를 줘서 목록 중간부터 시작한 경우에만 할 일이 있다
  /// ([hasPrev]). 첫 페이지부터 순서대로 받았다면 위쪽이 이미 다 있어 아무것도
  /// 하지 않는다.
  Future<void> loadPreviousMatches() async {
    if (_loadingMatches || _loadingPrevious || !_hasPrev) return;
    _loadingPrevious = true;
    _notify();
    try {
      var newMatches = 0;
      var attempts = 0;
      while (_hasPrev &&
          newMatches < _minMatchesPerLoad &&
          attempts < _maxPrefetchPages) {
        newMatches += await _fetchPreviousPage();
        attempts++;
        _notify();
      }
    } catch (_) {
      // 과거 로드 실패는 목록 사용을 막지 않는다 — 다음 시도에 다시 받는다.
    } finally {
      _loadingPrevious = false;
      _notify();
    }
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

  /// 과거 방향으로 받은 페이지를 목록 **앞**에 붙인다.
  ///
  /// 오늘 커서로 목록 중간부터 시작한 경우, 사용자가 위로 올리면 과거 페이지를
  /// 받아 여기로 들어온다. 서버가 이어지는 순서대로 내려주므로 그대로 앞에
  /// 붙이면 되고, 경계 날짜가 겹치면 한 그룹으로 합친다.
  void _prependIntoSchedule(List<ScheduleMatch> matches) {
    final groups = _groupByDate(matches);
    if (groups.isEmpty) return;
    if (_schedule.isNotEmpty &&
        _isSameDate(groups.last.date, _schedule.first.date)) {
      final first = _schedule.removeAt(0);
      _schedule.insert(
        0,
        ScheduleDay(
          date: first.date,
          matches: [...groups.last.matches, ...first.matches],
        ),
      );
      _schedule.insertAll(0, groups.take(groups.length - 1));
    } else {
      _schedule.insertAll(0, groups);
    }
  }

  /// 매치 목록을 같은 날짜끼리 [ScheduleDay] 로 묶는다. 받은 순서를 그대로 보존해
  /// 정렬 방향(서버 `sort`)에 상관없이 동작한다.
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

  /// 초기 '오늘로 스크롤' 대상까지 로드됐는지.
  ///
  /// 커서는 한 방향으로만 진행하므로, 오늘에 '도달'했다는 뜻은 정렬 방향에 따라
  /// 다르다. 최신→과거(DESC)면 미래부터 오니 오늘 이하가 나와야 도달이고,
  /// 과거→미래(ASC)면 과거부터 오니 오늘 이상이 나와야 도달이다.
  bool _hasReachedToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ascendingOrder = scheduleAscending;
    for (final day in _schedule) {
      final d = DateTime(day.date.year, day.date.month, day.date.day);
      if (ascendingOrder ? !d.isBefore(today) : !d.isAfter(today)) return true;
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
