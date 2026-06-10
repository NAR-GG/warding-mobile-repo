import 'package:flutter/foundation.dart';

import '../../model/match_calendar_day.dart';
import '../../model/team.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';
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
    AuthService? auth,
    OnboardingRepository? onboarding,
  }) : _displayMonth = _monthOf(initialMonth ?? DateTime.now()),
       _repository = repository ?? ScheduleRepository.instance,
       _teamPreferences =
           teamPreferences ?? TeamPreferenceRepository.instance,
       _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? OnboardingRepository.instance {
    loadCalendar();
    _loadPreferredTeam();
  }

  final ScheduleRepository _repository;
  final TeamPreferenceRepository _teamPreferences;
  final AuthService _auth;
  final OnboardingRepository _onboarding;

  bool _disposed = false;

  DateTime _displayMonth;

  /// 현재 표시 중인 월 (1일 0시로 정규화된 DateTime).
  DateTime get displayMonth => _displayMonth;

  /// 헤더에 표시할 'yyyy.MM' 라벨. 예: '2026.04'.
  String get monthLabel =>
      '${_displayMonth.year}.${_displayMonth.month.toString().padLeft(2, '0')}';

  /// 현재 월의 경기 캘린더 — 일(day) → 그 날 칸에 표시할 경기 칩 목록.
  Map<int, List<CalendarMatchBrief>> _matchesByDay = const {};
  Map<int, List<CalendarMatchBrief>> get matchesByDay => _matchesByDay;

  /// 온보딩에서 고른 선호 팀. 없으면(건너뛰기 등) null.
  Team? _preferredTeam;
  Team? get preferredTeam => _preferredTeam;

  /// 캘린더 조회에 적용 중인 리그 코드 (기본 'LCK').
  String _league = 'LCK';
  String get filterLeague => _league;

  /// 캘린더 조회에 적용 중인 팀 ID. null 이면 리그 전체.
  int? _teamId;
  int? get filterTeamId => _teamId;

  /// 헤더 팀 아이콘 선택(2px 테두리) 상태.
  /// 켜지면 선호 팀으로 캘린더를 필터링한다.
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
  /// 켜지면 선호 팀으로, 끄면 리그 전체로 캘린더를 다시 조회한다.
  void toggleTeamSelected() {
    _teamSelected = !_teamSelected;
    _teamId = _teamSelected ? _preferredTeam?.id : null;
    _notify();
    loadCalendar();
  }

  /// 필터 모달에서 고른 리그·팀을 적용하고 캘린더를 다시 조회한다.
  /// [teamId] 가 null 이면 리그 전체.
  void applyFilter({String? league, int? teamId}) {
    if (league != null && league.isNotEmpty) _league = league;
    _teamId = teamId;
    // 필터로 팀을 직접 골랐으면 헤더 선호팀 토글과 어긋나므로 해제해 둔다.
    _teamSelected = false;
    _notify();
    loadCalendar();
  }

  /// 날짜 피커에서 고른 날짜를 반영한다 — 그 달로 이동하고 칸을 강조한다.
  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    displayMonth = date; // 월이 다르면 정규화·통지·재조회한다.
    _notify(); // 같은 달이면 위에서 통지 안 됐을 수 있어 한 번 더.
  }

  /// 현재 표시 월의 경기 캘린더를 불러온다.
  ///
  /// `/api/mobile/schedules/calendar` 한 번으로 날짜별 칩 데이터까지 받는다.
  Future<void> loadCalendar() async {
    debugPrint('[Schedule] loadCalendar 시작: $_displayMonth '
        '(league=$_league, teamId=$_teamId)');
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final days = await _repository.fetchCalendar(
        _displayMonth,
        league: _league,
        teamId: _teamId,
      );
      _matchesByDay = {
        for (final day in days) day.date.day: day.matches,
      };
      final total =
          _matchesByDay.values.fold<int>(0, (sum, l) => sum + l.length);
      debugPrint('[Schedule] 완료: ${_matchesByDay.length}일, 총 $total경기');
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

  /// 응원 팀을 불러온다.
  ///
  /// 로그인 회원은 서버(`/api/auth/me`)의 `favoriteTeamId` 를 기준으로 팀을
  /// 매칭하고, 비로그인 등 실패 시 로컬 캐시로 폴백한다.
  Future<void> _loadPreferredTeam() async {
    try {
      final me = await _auth.fetchMe();
      final teamId = me.favoriteTeamId;
      Team? team;
      if (teamId != null) {
        final teams = await _onboarding.fetchTeams();
        for (final t in teams) {
          if (t.id == teamId) {
            team = t;
            break;
          }
        }
      }
      _preferredTeam = team;
    } catch (e) {
      // 비로그인 등은 로컬 캐시로 폴백.
      debugPrint('[Schedule] 응원팀 서버 조회 실패, 로컬 폴백: $e');
      _preferredTeam = await _teamPreferences.loadPreferredTeam();
    }
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
