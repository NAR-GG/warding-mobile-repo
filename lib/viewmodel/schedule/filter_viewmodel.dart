import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/schedule_filter_options.dart';
import '../../repository/live_activity/live_activity_logo_prefetcher.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 필터 모달에서 펼쳐진 드롭다운 식별자.
enum FilterDropdown { none, league, team }

/// 드롭다운 한 항목 — 표시 이름과 현재 선택 여부.
class FilterOption {
  const FilterOption({required this.name, required this.selected});
  final String name;
  final bool selected;
}

/// 필터 모달이 '조회'로 닫힐 때 화면에 돌려주는 선택 결과.
class FilterResult {
  const FilterResult({
    required this.leagues,
    this.teamIds = const [],
    this.resetMonth = false,
  });

  /// 선택한 리그 코드 목록 (예: ['LCK', 'LEC']). 전체 선택이면 ['ALL'].
  final List<String> leagues;

  /// 선택한 팀 ID 목록. 비어 있으면 리그 전체.
  final List<int> teamIds;

  /// 초기화 버튼을 눌렀으면 true → 캘린더 월도 현재 달로 되돌린다.
  final bool resetMonth;
}

/// 경기 필터 모달 ViewModel.
///
/// `/api/mobile/schedules/filters` 로 리그·팀 옵션을 받아 들고, 현재 선택값과
/// 모달을 열 때의 '이전 값'을 비교해 조회 버튼 활성 여부([isApplyEnabled])를
/// 정한다. 리그·팀 모두 다중 선택(체크박스)이며, 리그 선택이 바뀌면 그 조합에
/// 맞는 팀 목록을 다시 받아 온다.
///
/// 리그·팀 모두 선택 집합이 비어 있으면 '전체'로 취급한다 — 체크박스를 전부
/// 해제하면 자연히 '전체' 상태로 돌아간다.
class FilterViewModel extends ChangeNotifier {
  FilterViewModel({
    List<String>? initialLeagues,
    List<int>? initialTeamIds,
    ScheduleRepository? repository,
  })  : _repository = repository ?? ScheduleRepository.instance,
        _initialLeagueCodes = _stripAll(initialLeagues),
        _initialTeamIds = (initialTeamIds ?? const []).toSet(),
        _selectedLeagueCodes = _stripAll(initialLeagues),
        _selectedTeamIds = (initialTeamIds ?? const []).toSet() {
    _load(_teamOptionsScopes());
  }

  /// 리그·팀 드롭다운의 '전체' 가상 옵션 라벨. 선택 해제 시 이 상태로 돌아간다.
  static const String allLabel = '전체';

  /// '전체' 조회 시 서버에 보낼 리그 코드.
  static const String allLeagueCode = 'ALL';

  final ScheduleRepository _repository;

  /// 모달을 열 때의 '이전 값' — 조회 버튼 활성 비교 기준. 'ALL'/전체는 빈 집합으로 정규화한다.
  final Set<String> _initialLeagueCodes;
  final Set<int> _initialTeamIds;

  List<FilterLeague> _leagues = const [];
  List<FilterTeam> _teams = const [];

  /// 현재 선택된 리그 코드 집합. 비어 있으면 '전체'.
  Set<String> _selectedLeagueCodes;

  /// 현재 선택된 팀 ID 집합. 비어 있으면 '전체'.
  Set<int> _selectedTeamIds;

  bool _loading = false;
  bool get loading => _loading;

  FilterDropdown _openDropdown = FilterDropdown.none;
  FilterDropdown get openDropdown => _openDropdown;

  /// 리그 드롭다운 항목 — 선택된 항목이 앞으로 정렬된다(각 그룹 내 원래 순서 유지).
  /// 서버가 이미 맨 앞에 '전체' 옵션을 포함해 준다.
  List<FilterOption> get leagueOptions => _ordered(
        _leagues.map((l) => l.name).toList(),
        (name) => name == allLabel
            ? _selectedLeagueCodes.isEmpty
            : _selectedLeagueCodes.contains(_leagueCodeOf(name)),
      );

  /// 팀 드롭다운 항목 — '전체'를 클라이언트에서 맨 앞에 추가한다(서버 목록은 실제 팀만).
  List<FilterOption> get teamOptions => _ordered(
        [allLabel, ..._teams.map((t) => t.teamName)],
        (name) => name == allLabel
            ? _selectedTeamIds.isEmpty
            : _selectedTeamIds.contains(_teamIdOf(name)),
      );

  /// 셀렉트 박스에 표시할 리그 요약 텍스트. '전체'면 null(placeholder 표시).
  String? get selectedLeagueSummary => _selectedLeagueCodes.isEmpty
      ? null
      : _leagues
          .where((l) => _selectedLeagueCodes.contains(l.code))
          .map((l) => l.name)
          .join(', ');

  /// 셀렉트 박스에 표시할 팀 요약 텍스트. '전체'면 null(placeholder 표시).
  String? get selectedTeamSummary => _selectedTeamIds.isEmpty
      ? null
      : _teams
          .where((t) => _selectedTeamIds.contains(t.teamId))
          .map((t) => t.teamName)
          .join(', ');

  /// 초기화 버튼을 눌렀는지 여부. 초기화 후 조회를 누를 수 있게 한다.
  bool _wasReset = false;

  /// 선택값이 이전 값과 하나라도 달라졌거나 초기화됐으면 true → 조회 버튼 활성.
  bool get isApplyEnabled =>
      _wasReset ||
      !setEquals(_selectedLeagueCodes, _initialLeagueCodes) ||
      !setEquals(_selectedTeamIds, _initialTeamIds);

  /// 조회 버튼을 눌렀을 때 화면에 돌려줄 결과.
  FilterResult get result => FilterResult(
        leagues: _selectedLeagueCodes.isEmpty
            ? [allLeagueCode]
            : _selectedLeagueCodes.toList(),
        teamIds: _selectedTeamIds.toList(),
        resetMonth: _wasReset,
      );

  /// 드롭다운을 펼치거나 접는다. 이미 펼친 걸 다시 누르면 접힌다.
  void toggleDropdown(FilterDropdown which) {
    _openDropdown = _openDropdown == which ? FilterDropdown.none : which;
    notifyListeners();
  }

  /// 이름으로 리그 체크박스를 토글한다. '전체'를 선택하면 다른 선택을 모두 지운다.
  /// 리그 선택이 바뀌면 팀 선택을 초기화하고, 그 조합에 맞는 팀 목록을 다시 받아 온다.
  void toggleLeague(String name) {
    if (name == allLabel) {
      if (_selectedLeagueCodes.isEmpty) return; // 이미 '전체'.
      _selectedLeagueCodes = {};
    } else {
      final code = _leagueCodeOf(name);
      if (code == null) return;
      final next = Set<String>.from(_selectedLeagueCodes);
      next.contains(code) ? next.remove(code) : next.add(code);
      _selectedLeagueCodes = next;
    }
    _selectedTeamIds = {}; // 리그가 바뀌면 팀 선택은 초기화.
    notifyListeners();
    _load(_teamOptionsScopes());
  }

  /// 이름으로 팀 체크박스를 토글한다. '전체'를 선택하면 다른 선택을 모두 지운다.
  void toggleTeam(String name) {
    if (name == allLabel) {
      if (_selectedTeamIds.isEmpty) return; // 이미 '전체'.
      _selectedTeamIds = {};
      notifyListeners();
      return;
    }
    final teamId = _teamIdOf(name);
    if (teamId == null) return;
    final next = Set<int>.from(_selectedTeamIds);
    next.contains(teamId) ? next.remove(teamId) : next.add(teamId);
    _selectedTeamIds = next;
    notifyListeners();
  }

  /// 초기화 — 리그·팀 선택을 모두 해제하고 전체로 되돌린다.
  void reset() {
    _selectedLeagueCodes = {};
    _selectedTeamIds = {};
    _wasReset = true;
    _openDropdown = FilterDropdown.none;
    notifyListeners();
    _load([allLeagueCode]);
  }

  /// 옵션 조회 세대. 리그 체크를 빠르게 여러 번 누르면 조회가 겹치는데,
  /// 응답 순서는 보장되지 않는다. 자기 세대가 최신이 아니면 결과를 버려
  /// 늦게 도착한 옛 조회가 엉뚱한 팀 목록을 덮어쓰는 걸 막는다.
  int _loadId = 0;

  /// [leagues] 각각의 필터 옵션(리그 전체 목록 + 그 리그 팀)을 받아 합친다.
  /// `/filters` 가 단일 리그만 받는 API라, 리그를 복수 선택했으면 리그별로
  /// 병렬 조회해 팀 목록을 teamId 기준 중복 제거하며 합친다.
  Future<void> _load(List<String> leagues) async {
    final loadId = ++_loadId;
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait(
        leagues.map((l) => _repository.fetchFilterOptions(league: l)),
      );
      if (loadId != _loadId) return; // 더 최신 선택의 조회가 이미 떠 있다.
      _leagues = results.first.leagues;
      final mergedTeams = <int, FilterTeam>{};
      for (final options in results) {
        for (final team in options.teams) {
          mergedTeams[team.teamId] = team;
        }
      }
      _teams = mergedTeams.values.toList();

      // 실시간 카드 로고를 미리 저장해 둔다. 서버가 만든 카드는 앱 없이
      // 렌더되므로 그 전에 디스크에 있어야 로고가 보인다. 이미 받아둔 팀은
      // 존재 확인만 하고 넘어가고, 여기서 기다리지 않는다.
      unawaited(liveActivityLogoPrefetcher.prefetchTeams(_teams));
    } catch (_) {
      // 옵션 로드 실패 시 빈 목록 유지 — 모달은 떠 있되 항목만 비어 있다.
    } finally {
      // 최신 조회만 로딩을 내린다. 구버전이 내리면 아직 받는 중인데 목록이
      // 비어 보인다.
      if (loadId == _loadId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// 팀 옵션 조회에 쓸 리그 코드 목록. 선택된 리그가 있으면 그 리그들 각각,
  /// 없으면(전체) 서버에 'ALL' 하나만 보내 전 리그 팀 목록을 받는다.
  List<String> _teamOptionsScopes() =>
      _selectedLeagueCodes.isEmpty
          ? [allLeagueCode]
          : _selectedLeagueCodes.toList();

  String? _leagueCodeOf(String name) {
    final code = _leagues
        .firstWhere((l) => l.name == name, orElse: () => const FilterLeague(code: '', name: ''))
        .code;
    return code.isEmpty ? null : code;
  }

  int? _teamIdOf(String name) {
    final id = _teams
        .firstWhere((t) => t.teamName == name,
            orElse: () => const FilterTeam(teamId: 0, teamName: '', teamCode: '', teamImageUrl: ''))
        .teamId;
    return id == 0 ? null : id;
  }

  /// 선택된 항목을 앞으로, 나머지는 뒤로(각 그룹 내 원래 순서 유지).
  List<FilterOption> _ordered(List<String> names, bool Function(String) isSelected) {
    final selected = <FilterOption>[];
    final unselected = <FilterOption>[];
    for (final name in names) {
      final option = FilterOption(name: name, selected: isSelected(name));
      (option.selected ? selected : unselected).add(option);
    }
    return [...selected, ...unselected];
  }

  static Set<String> _stripAll(List<String>? leagues) =>
      (leagues ?? const []).where((l) => l != allLeagueCode).toSet();
}
