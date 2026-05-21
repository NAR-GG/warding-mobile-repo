import 'package:flutter/foundation.dart';

/// 필터 모달에서 펼쳐진 드롭다운 식별자.
enum FilterDropdown { none, league, team }

/// 경기 필터 모달 ViewModel.
///
/// 하드코딩된 리그·팀 목록을 들고, 현재 선택값과 모달을 열 때의
/// '이전 값'을 비교해 조회 버튼 활성 여부([isApplyEnabled])를 정한다.
class FilterViewModel extends ChangeNotifier {
  FilterViewModel({String? initialLeague, String? initialTeam})
    : _initialLeague = initialLeague,
      _initialTeam = initialTeam,
      _selectedLeague = initialLeague,
      _selectedTeam = initialTeam;

  /// 하드코딩 리그 목록.
  static const List<String> leagues = ['LCK', 'LPL', 'LEC', 'LCS'];

  /// 하드코딩 팀 목록.
  static const List<String> teams = [
    'T1',
    'Gen.G',
    'KT Rolster',
    'DRX',
    'Dplus KIA',
    'Hanwha Life',
  ];

  /// 모달을 열 때의 '이전 값' — 조회 버튼 활성 비교 기준.
  final String? _initialLeague;
  final String? _initialTeam;

  String? _selectedLeague;
  String? get selectedLeague => _selectedLeague;

  String? _selectedTeam;
  String? get selectedTeam => _selectedTeam;

  FilterDropdown _openDropdown = FilterDropdown.none;
  FilterDropdown get openDropdown => _openDropdown;

  /// 선택값이 이전 값과 하나라도 달라졌으면 true → 조회 버튼 활성.
  bool get isApplyEnabled =>
      _selectedLeague != _initialLeague || _selectedTeam != _initialTeam;

  /// 드롭다운을 펼치거나 접는다. 이미 펼친 걸 다시 누르면 접힌다.
  void toggleDropdown(FilterDropdown which) {
    _openDropdown = _openDropdown == which ? FilterDropdown.none : which;
    notifyListeners();
  }

  /// 리그를 선택하고 드롭다운을 접는다.
  void selectLeague(String league) {
    _selectedLeague = league;
    _openDropdown = FilterDropdown.none;
    notifyListeners();
  }

  /// 팀을 선택하고 드롭다운을 접는다.
  void selectTeam(String team) {
    _selectedTeam = team;
    _openDropdown = FilterDropdown.none;
    notifyListeners();
  }

  /// 초기화 — 리그·팀 선택을 모두 해제한다.
  void reset() {
    _selectedLeague = null;
    _selectedTeam = null;
    _openDropdown = FilterDropdown.none;
    notifyListeners();
  }
}
