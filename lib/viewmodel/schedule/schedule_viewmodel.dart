import 'package:flutter/foundation.dart';

import '../../model/schedule_match.dart';
import '../../model/team.dart';
import '../../repository/preference/team_preference_repository.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 경기 일정 화면 ViewModel.
///
/// 현재 표시 중인 '월'과, 그 달의 경기 캘린더(날짜별 경기 목록)를 들고 있다.
class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel({
    DateTime? initialMonth,
    ScheduleRepository? repository,
    TeamPreferenceRepository? teamPreferences,
  }) : _displayMonth = _monthOf(initialMonth ?? DateTime.now()),
       _repository = repository ?? ScheduleRepository.instance,
       _teamPreferences =
           teamPreferences ?? TeamPreferenceRepository.instance {
    loadCalendar();
    _loadPreferredTeam();
  }

  final ScheduleRepository _repository;
  final TeamPreferenceRepository _teamPreferences;

  bool _disposed = false;

  DateTime _displayMonth;

  /// 현재 표시 중인 월 (1일 0시로 정규화된 DateTime).
  DateTime get displayMonth => _displayMonth;

  /// 헤더에 표시할 'yyyy.MM' 라벨. 예: '2026.04'.
  String get monthLabel =>
      '${_displayMonth.year}.${_displayMonth.month.toString().padLeft(2, '0')}';

  /// 현재 월의 경기 캘린더 — 일(day) → 그 날 경기 목록.
  Map<int, List<ScheduleMatch>> _matchesByDay = const {};
  Map<int, List<ScheduleMatch>> get matchesByDay => _matchesByDay;

  /// 온보딩에서 고른 선호 팀. 없으면(건너뛰기 등) null.
  Team? _preferredTeam;
  Team? get preferredTeam => _preferredTeam;

  /// 헤더 팀 아이콘 선택(2px 테두리) 상태.
  /// API 에 팀 필터 파라미터가 생기면 이 상태로 경기 필터링을 연결한다.
  bool _teamSelected = false;
  bool get teamSelected => _teamSelected;

  /// 날짜 피커에서 고른 날짜. 캘린더에서 그 칸 배경을 강조한다.
  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  /// 캘린더 조회 진행 중 여부.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 마지막 조회 실패 시 에러. 성공하면 null.
  Object? _error;
  Object? get error => _error;

  /// 표시 월을 변경한다. 캘린더에서 월 이동 시 호출한다.
  set displayMonth(DateTime month) {
    final normalized = _monthOf(month);
    if (normalized == _displayMonth) return;
    _displayMonth = normalized;
    notifyListeners();
    loadCalendar();
  }

  /// 표시 월을 [delta] 개월 이동한다. 캘린더 좌우 스와이프용.
  /// DateTime 생성자가 12월 초과·0 이하 월을 연도까지 정규화한다.
  void shiftMonth(int delta) {
    displayMonth = DateTime(_displayMonth.year, _displayMonth.month + delta);
  }

  /// 헤더 팀 아이콘 선택 상태를 토글한다.
  void toggleTeamSelected() {
    _teamSelected = !_teamSelected;
    _notify();
  }

  /// 날짜 피커에서 고른 날짜를 반영한다 — 그 달로 이동하고 칸을 강조한다.
  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    displayMonth = date; // 월이 다르면 정규화·통지·재조회한다.
    _notify(); // 같은 달이면 위에서 통지 안 됐을 수 있어 한 번 더.
  }

  /// 현재 표시 월의 경기 캘린더를 불러온다.
  ///
  /// 1) `/schedule/calendar` 로 경기가 있는 날짜를 받고,
  /// 2) 그 날짜마다 경기 목록을 병렬로 조회한다.
  Future<void> loadCalendar() async {
    debugPrint('[Schedule] loadCalendar 시작: $_displayMonth');
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final days = await _repository.fetchCalendar(_displayMonth);
      // 경기일마다 경기 목록을 병렬 조회. 일부 날짜가 실패해도
      // 그 날만 빈 목록으로 두고 나머지는 살린다.
      final entries = await Future.wait(
        days.map((day) async {
          try {
            final matches = await _repository.fetchMatchesByDate(day.date);
            return MapEntry(day.date.day, matches);
          } catch (e) {
            debugPrint('[Schedule] ${day.date} 경기 조회 실패: $e');
            return MapEntry(day.date.day, <ScheduleMatch>[]);
          }
        }),
      );
      _matchesByDay = Map.fromEntries(entries);
      final total =
          _matchesByDay.values.fold<int>(0, (sum, l) => sum + l.length);
      debugPrint('[Schedule] 완료: ${_matchesByDay.length}일, 총 $total경기');
      for (final e in _matchesByDay.entries.take(3)) {
        debugPrint('[Schedule]   ${e.key}일: '
            '${e.value.map((m) => '${m.teamA.teamCode} vs ${m.teamB.teamCode}').toList()}');
      }
    } catch (e, st) {
      _error = e;
      _matchesByDay = const {};
      debugPrint('[Schedule] loadCalendar 에러: $e');
      debugPrint('$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// 로컬에 저장된 선호 팀을 불러온다.
  Future<void> _loadPreferredTeam() async {
    _preferredTeam = await _teamPreferences.loadPreferredTeam();
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 연·월만 남기고 1일 0시로 정규화한다.
  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);
}
