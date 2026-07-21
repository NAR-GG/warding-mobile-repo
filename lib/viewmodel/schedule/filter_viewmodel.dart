import 'package:flutter/foundation.dart';

import '../../model/schedule_filter_options.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 필터 모달에서 펼쳐진 드롭다운 식별자.
enum FilterDropdown { none, league, team }

/// 필터 모달이 '조회'로 닫힐 때 화면에 돌려주는 선택 결과.
class FilterResult {
  const FilterResult({
    required this.leagues,
    required this.teamIds,
    this.resetMonth = false,
  });

  /// 선택한 리그 코드 목록 (멀티 선택). 비어 있으면 전체.
  final Set<String> leagues;

  /// 선택한 팀 ID 목록 (멀티 선택). 비어 있으면 전체.
  final Set<int> teamIds;

  /// 초기화 버튼을 눌렀으면 true → 캘린더 월도 현재 달로 되돌린다.
  final bool resetMonth;
}

/// 경기 필터 모달 ViewModel.
class FilterViewModel extends ChangeNotifier {
  FilterViewModel({
    Set<String>? initialLeagues,
    Set<int>? initialTeamIds,
    ScheduleRepository? repository,
  })  : _repository = repository ?? ScheduleRepository.instance,
        _initialLeagues = initialLeagues ?? const {},
        _initialTeamIds = initialTeamIds ?? const {},
        _selectedLeagueCodes = Set<String>.from(initialLeagues ?? const {}),
        _selectedTeamIds = Set<int>.from(initialTeamIds ?? const {}) {
    _load(allLeagueCode);
  }

  static const String allLeagueLabel = '전체';
  static const String allLeagueCode = 'ALL';

  final ScheduleRepository _repository;

  final Set<String> _initialLeagues;
  final Set<int> _initialTeamIds;

  List<FilterLeague> _leagues = const [];
  List<FilterTeam> _teams = const [];

  Set<String> _selectedLeagueCodes;
  Set<int> _selectedTeamIds;

  bool _loading = false;
  bool get loading => _loading;

  FilterDropdown _openDropdown = FilterDropdown.none;
  FilterDropdown get openDropdown => _openDropdown;

  // ── 리그 ──

  List<String> get leagueNames =>
      _leagues.where((l) => l.code != allLeagueCode).map((l) => l.name).toList();

  List<FilterLeague> get leagues => _leagues;

  Set<String> get selectedLeagueCodes => _selectedLeagueCodes;

  String? get selectedLeagueSummary {
    if (_selectedLeagueCodes.isEmpty) return null;
    if (_selectedLeagueCodes.contains(allLeagueCode)) return allLeagueLabel;
    if (_selectedLeagueCodes.length == 1) {
      final code = _selectedLeagueCodes.first;
      for (final l in _leagues) {
        if (l.code == code) return l.name;
      }
      return code;
    }
    final first = _selectedLeagueCodes.first;
    String firstName = first;
    for (final l in _leagues) {
      if (l.code == first) {
        firstName = l.name;
        break;
      }
    }
    return '$firstName 외 ${_selectedLeagueCodes.length - 1}개';
  }

  String? _codeForName(String name) {
    if (name == allLeagueLabel) return allLeagueCode;
    for (final l in _leagues) {
      if (l.name == name) return l.code;
    }
    return null;
  }

  void toggleLeagueByName(String name) {
    final code = _codeForName(name);
    if (code == null) return;
    if (_selectedLeagueCodes.contains(code)) {
      _selectedLeagueCodes.remove(code);
    } else {
      _selectedLeagueCodes.remove(allLeagueCode);
      _selectedLeagueCodes.add(code);
    }
    _selectedTeamIds = {};
    notifyListeners();
  }

  bool isLeagueSelectedByName(String name) {
    final code = _codeForName(name);
    return code != null && _selectedLeagueCodes.contains(code);
  }

  // ── 팀 ──

  List<String> get teamNames => _teams.map((t) => t.teamName).toList();

  Set<int> get selectedTeamIds => _selectedTeamIds;

  String? get selectedTeamSummary {
    if (_selectedTeamIds.isEmpty) return null;
    if (_selectedTeamIds.length == 1) {
      final id = _selectedTeamIds.first;
      for (final t in _teams) {
        if (t.teamId == id) return t.teamName;
      }
      return null;
    }
    final first = _selectedTeamIds.first;
    String firstName = '';
    for (final t in _teams) {
      if (t.teamId == first) {
        firstName = t.teamName;
        break;
      }
    }
    return '$firstName 외 ${_selectedTeamIds.length - 1}개';
  }

  void toggleTeamByName(String name) {
    final team = _teams.firstWhere(
      (t) => t.teamName == name,
      orElse: () => const FilterTeam(
        teamId: 0, teamName: '', teamCode: '', teamImageUrl: '',
      ),
    );
    if (team.teamId == 0) return;
    if (_selectedTeamIds.contains(team.teamId)) {
      _selectedTeamIds.remove(team.teamId);
    } else {
      _selectedTeamIds.add(team.teamId);
    }
    notifyListeners();
  }

  bool isTeamSelectedByName(String name) {
    final team = _teams.firstWhere(
      (t) => t.teamName == name,
      orElse: () => const FilterTeam(
        teamId: 0, teamName: '', teamCode: '', teamImageUrl: '',
      ),
    );
    return team.teamId != 0 && _selectedTeamIds.contains(team.teamId);
  }

  // ── 공통 ──

  bool _wasReset = false;

  bool get isApplyEnabled =>
      _wasReset ||
      !_setEquals(_selectedLeagueCodes, _initialLeagues) ||
      !_setIntEquals(_selectedTeamIds, _initialTeamIds);

  FilterResult get result => FilterResult(
        leagues: Set<String>.from(_selectedLeagueCodes),
        teamIds: Set<int>.from(_selectedTeamIds),
        resetMonth: _wasReset,
      );

  void toggleDropdown(FilterDropdown which) {
    _openDropdown = _openDropdown == which ? FilterDropdown.none : which;
    notifyListeners();
  }

  void reset() {
    _selectedLeagueCodes = {};
    _selectedTeamIds = {};
    _wasReset = true;
    _openDropdown = FilterDropdown.none;
    notifyListeners();
    _load(allLeagueCode);
  }

  Future<void> _load(String league) async {
    _loading = true;
    notifyListeners();
    try {
      final options = await _repository.fetchFilterOptions(league: league);
      _leagues = options.leagues;
      _teams = options.teams;
    } catch (_) {
      // 옵션 로드 실패 시 빈 목록 유지.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final e in a) {
      if (!b.contains(e)) return false;
    }
    return true;
  }

  static bool _setIntEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    for (final e in a) {
      if (!b.contains(e)) return false;
    }
    return true;
  }
}
