import 'package:flutter/foundation.dart';

import '../../model/schedule_filter_options.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 필터 모달에서 펼쳐진 드롭다운 식별자.
enum FilterDropdown { none, league, team }

/// 필터 모달이 '조회'로 닫힐 때 화면에 돌려주는 선택 결과.
class FilterResult {
  const FilterResult({required this.league, this.teamId});

  /// 선택한 리그 코드 (예: 'LCK').
  final String league;

  /// 선택한 팀 ID. null 이면 리그 전체.
  final int? teamId;
}

/// 경기 필터 모달 ViewModel.
///
/// `/api/mobile/schedules/filters` 로 리그·팀 옵션을 받아 들고, 현재 선택값과
/// 모달을 열 때의 '이전 값'을 비교해 조회 버튼 활성 여부([isApplyEnabled])를
/// 정한다. 리그를 바꾸면 그 리그 소속 팀 목록을 다시 받아 온다.
class FilterViewModel extends ChangeNotifier {
  FilterViewModel({
    String? initialLeague,
    int? initialTeamId,
    ScheduleRepository? repository,
  })  : _repository = repository ?? ScheduleRepository.instance,
        _initialLeague = initialLeague,
        _initialTeamId = initialTeamId,
        _selectedLeagueCode = initialLeague,
        _selectedTeamId = initialTeamId {
    _load(initialLeague ?? 'LCK');
  }

  final ScheduleRepository _repository;

  /// 모달을 열 때의 '이전 값' — 조회 버튼 활성 비교 기준.
  final String? _initialLeague;
  final int? _initialTeamId;

  List<FilterLeague> _leagues = const [];
  List<FilterTeam> _teams = const [];

  String? _selectedLeagueCode;
  int? _selectedTeamId;

  bool _loading = false;
  bool get loading => _loading;

  FilterDropdown _openDropdown = FilterDropdown.none;
  FilterDropdown get openDropdown => _openDropdown;

  /// 드롭다운에 보여줄 리그 이름 목록.
  List<String> get leagueNames => _leagues.map((l) => l.name).toList();

  /// 드롭다운에 보여줄 팀 이름 목록.
  List<String> get teamNames => _teams.map((t) => t.teamName).toList();

  /// 셀렉트 박스에 표시할 현재 리그 이름. 미선택이면 null.
  String? get selectedLeagueName {
    final code = _selectedLeagueCode;
    if (code == null) return null;
    for (final l in _leagues) {
      if (l.code == code) return l.name;
    }
    return null;
  }

  /// 셀렉트 박스에 표시할 현재 팀 이름. 미선택이면 null.
  String? get selectedTeamName {
    final id = _selectedTeamId;
    if (id == null) return null;
    for (final t in _teams) {
      if (t.teamId == id) return t.teamName;
    }
    return null;
  }

  /// 선택값이 이전 값과 하나라도 달라졌으면 true → 조회 버튼 활성.
  bool get isApplyEnabled =>
      _selectedLeagueCode != _initialLeague ||
      _selectedTeamId != _initialTeamId;

  /// 조회 버튼을 눌렀을 때 화면에 돌려줄 결과.
  FilterResult get result => FilterResult(
        league: _selectedLeagueCode ?? 'LCK',
        teamId: _selectedTeamId,
      );

  /// 드롭다운을 펼치거나 접는다. 이미 펼친 걸 다시 누르면 접힌다.
  void toggleDropdown(FilterDropdown which) {
    _openDropdown = _openDropdown == which ? FilterDropdown.none : which;
    notifyListeners();
  }

  /// 이름으로 리그를 선택하고, 그 리그의 팀 목록을 다시 받아 온다.
  void selectLeagueByName(String name) {
    final league = _leagues.firstWhere(
      (l) => l.name == name,
      orElse: () => const FilterLeague(code: '', name: ''),
    );
    if (league.code.isEmpty || league.code == _selectedLeagueCode) {
      _openDropdown = FilterDropdown.none;
      notifyListeners();
      return;
    }
    _selectedLeagueCode = league.code;
    _selectedTeamId = null; // 리그가 바뀌면 팀 선택은 초기화.
    _openDropdown = FilterDropdown.none;
    notifyListeners();
    _load(league.code);
  }

  /// 이름으로 팀을 선택하고 드롭다운을 접는다.
  void selectTeamByName(String name) {
    final team = _teams.firstWhere(
      (t) => t.teamName == name,
      orElse: () => const FilterTeam(
        teamId: 0,
        teamName: '',
        teamCode: '',
        teamImageUrl: '',
      ),
    );
    _selectedTeamId = team.teamId == 0 ? null : team.teamId;
    _openDropdown = FilterDropdown.none;
    notifyListeners();
  }

  /// 초기화 — 팀 선택을 해제한다 (리그는 유지).
  void reset() {
    _selectedTeamId = null;
    _openDropdown = FilterDropdown.none;
    notifyListeners();
  }

  /// [league] 의 필터 옵션(리그 전체 목록 + 그 리그 팀)을 받아 온다.
  Future<void> _load(String league) async {
    _loading = true;
    notifyListeners();
    try {
      final options = await _repository.fetchFilterOptions(league: league);
      _leagues = options.leagues;
      _teams = options.teams;
      // 첫 로드에서 리그가 아직 안 정해졌으면 서버 기본값을 따른다.
      _selectedLeagueCode ??=
          options.defaultLeague.isNotEmpty ? options.defaultLeague : league;
    } catch (_) {
      // 옵션 로드 실패 시 빈 목록 유지 — 모달은 떠 있되 항목만 비어 있다.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
