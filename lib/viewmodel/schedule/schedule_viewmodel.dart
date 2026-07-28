import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/match_calendar_day.dart';
import '../../model/team.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/preference/filter_preference_repository.dart';
import '../../repository/preference/team_preference_repository.dart';
import '../../repository/schedule/schedule_repository.dart';
import '../../util/home_widget_service.dart';

/// 경기 일정 화면 ViewModel.
///
/// 현재 표시 중인 '월'과, 그 달의 경기 캘린더(날짜별 경기 목록)를 들고 있다.
class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel({
    DateTime? initialMonth,
    ScheduleRepository? repository,
    TeamPreferenceRepository? teamPreferences,
    FilterPreferenceRepository? filterPreferences,
    AuthService? auth,
    OnboardingRepository? onboarding,
  }) : _displayMonth = _monthOf(initialMonth ?? DateTime.now()),
       _repository = repository ?? ScheduleRepository.instance,
       _teamPreferences =
           teamPreferences ?? TeamPreferenceRepository.instance,
       _filterPreferences =
           filterPreferences ?? FilterPreferenceRepository.instance,
       _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? OnboardingRepository.instance {
    _init();
    _loadPreferredTeam();
  }

  final ScheduleRepository _repository;
  final TeamPreferenceRepository _teamPreferences;
  final FilterPreferenceRepository _filterPreferences;
  final AuthService _auth;
  final OnboardingRepository _onboarding;

  /// 마지막 사용 필터를 복원한 뒤 첫 캘린더를 조회한다.
  /// 저장값이 없으면(첫 실행) 기본값 그대로 '전체'.
  Future<void> _init() async {
    final saved =
        await _filterPreferences.load(FilterPreferenceRepository.scheduleKey);
    if (saved != null) {
      final leagues = (saved['leagues'] as List?)?.cast<String>();
      _leagues = leagues != null && leagues.isNotEmpty ? leagues : ['ALL'];
      _teamIds = (saved['teamIds'] as List?)?.cast<int>() ?? const [];
      _teamSelected = (saved['teamSelected'] as bool?) ?? false;
    }
    loadCalendar();
  }

  /// 현재 필터를 저장한다. 실패해도 조회는 계속되므로 기다리지 않는다.
  void _persistFilter() {
    unawaited(_filterPreferences.save(FilterPreferenceRepository.scheduleKey, {
      'leagues': _leagues,
      'teamIds': _teamIds,
      'teamSelected': _teamSelected,
    }));
  }

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

  /// 캘린더 조회에 적용 중인 리그 코드 목록 (기본 ['ALL'] = 전체 리그).
  List<String> _leagues = const ['ALL'];
  List<String> get filterLeagues => _leagues;

  /// 캘린더 조회에 적용 중인 팀 ID 목록. 비어 있으면 리그 전체.
  List<int> _teamIds = const [];
  List<int> get filterTeamIds => _teamIds;

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
    final preferredId = _preferredTeam?.id;
    _teamIds = _teamSelected && preferredId != null ? [preferredId] : const [];
    _persistFilter();
    _updateWidgetFilterState();
    _notify();
    loadCalendar();
  }

  /// 필터 모달에서 고른 리그·팀을 적용하고 캘린더를 다시 조회한다.
  /// [teamIds] 가 비어 있으면 리그 전체.
  /// [resetMonth] 가 true 면 현재 달로 되돌린다 (초기화 버튼).
  void applyFilter({
    List<String>? leagues,
    List<int>? teamIds,
    bool resetMonth = false,
  }) {
    if (leagues != null && leagues.isNotEmpty) _leagues = leagues;
    _teamIds = teamIds ?? const [];
    // 필터로 팀을 직접 골랐으면 헤더 선호팀 토글과 어긋나므로 해제해 둔다.
    _teamSelected = false;
    if (resetMonth) {
      _displayMonth = _monthOf(DateTime.now());
      _selectedDate = null;
    }
    _persistFilter();
    _updateWidgetFilterState();
    _notify();
    loadCalendar();
  }

  /// 위젯에 필터/팀 선택 상태를 전달한다.
  void _updateWidgetFilterState() {
    final hasFilter = !(_leagues.length == 1 && _leagues.first == 'ALL') ||
        _teamIds.isNotEmpty;
    unawaited(HomeWidgetService.updateFilterState(
      hasFilter: hasFilter,
      teamSelected: _teamSelected,
    ));
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
        '(leagues=$_leagues, teamIds=$_teamIds)');
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final days = await _repository.fetchCalendar(
        _displayMonth,
        leagues: _leagues,
        teamIds: _teamIds,
      );
      _matchesByDay = {
        for (final day in days) day.date.day: day.matches,
      };
      final total =
          _matchesByDay.values.fold<int>(0, (sum, l) => sum + l.length);
      debugPrint('[Schedule] 완료: ${_matchesByDay.length}일, 총 $total경기');
      // 홈 화면 위젯에 최신 캘린더 데이터 전달 (필터 포함)
      unawaited(HomeWidgetService.updateCalendar(
        month: _displayMonth,
        matchesByDay: _matchesByDay,
        leagues: _leagues,
        teamIds: _teamIds,
      ));
    } catch (e, st) {
      _error = appStrings?.scheduleLoadFailed ?? 'Failed to load schedule';
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
    // 홈 화면 위젯에 응원팀 정보 전달
    unawaited(HomeWidgetService.updatePreferredTeam(_preferredTeam));
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
