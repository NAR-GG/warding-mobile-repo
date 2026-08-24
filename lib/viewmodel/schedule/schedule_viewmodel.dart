import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/calendar_week_start.dart';
import '../../model/match_calendar_day.dart';
import '../../model/notice.dart';
import '../../model/team.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/notice/notice_repository.dart';
import '../../repository/onboarding/onboarding_repository.dart';
import '../../repository/preference/calendar_week_start_preference_repository.dart';
import '../../repository/preference/filter_preference_repository.dart';
import '../../repository/preference/notice_preference_repository.dart';
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
    NoticeRepository? notices,
    NoticePreferenceRepository? noticePreferences,
    CalendarWeekStartPreferenceRepository? weekStartPreferences,
  }) : _displayMonth = _monthOf(initialMonth ?? DateTime.now()),
       _repository = repository ?? ScheduleRepository.instance,
       _teamPreferences =
           teamPreferences ?? TeamPreferenceRepository.instance,
       _filterPreferences =
           filterPreferences ?? FilterPreferenceRepository.instance,
       _auth = auth ?? AuthService.instance,
       _onboarding = onboarding ?? OnboardingRepository.instance,
       _notices = notices ?? NoticeRepository.instance,
       _noticePreferences =
           noticePreferences ?? NoticePreferenceRepository.instance,
       _weekStartPreferences = weekStartPreferences ??
           CalendarWeekStartPreferenceRepository.instance {
    _weekStart = _weekStartPreferences.cachedValue ?? CalendarWeekStart.monday;
    // 스플래시가 미리 받아 둔 공지가 있으면 첫 프레임부터 그 상태로 그린다.
    // 배너는 캘린더 위에 얹혀 있어서, 뒤늦게 나타나면 캘린더를 아래로 밀고
    // 높이까지 줄여 화면이 한 번 출렁인다.
    _promotedNotices = _notices.cachedPromoted ?? const [];
    _dismissedNoticeIds = _noticePreferences.cachedValue ?? const {};
    _init();
    _loadPreferredTeam();
    _loadPromotedNotice();
    _restoreWeekStart();
  }

  final ScheduleRepository _repository;
  final TeamPreferenceRepository _teamPreferences;
  final FilterPreferenceRepository _filterPreferences;
  final AuthService _auth;
  final OnboardingRepository _onboarding;
  final NoticeRepository _notices;
  final NoticePreferenceRepository _noticePreferences;
  final CalendarWeekStartPreferenceRepository _weekStartPreferences;

  // ── 캘린더 상단 공지 띠배너 ─────────────────────────────────────

  List<Notice> _promotedNotices = const [];
  Set<int> _dismissedNoticeIds = const {};

  /// 띠배너에 노출할 공지 — 닫지 않은 것 중 최신 발행. null 이면 배너 미표시.
  Notice? get promotedNotice {
    for (final notice in _promotedNotices) {
      if (!_dismissedNoticeIds.contains(notice.id)) return notice;
    }
    return null;
  }

  /// 배너 공지 목록을 불러온다. ✕로 닫았던 공지는 건너뛴다.
  /// 실패해도 캘린더 화면 자체는 정상 동작해야 하므로 조용히 무시한다.
  ///
  /// 생성자에서 캐시로 이미 맞춘 값과 결과가 같으면 알리지 않는다 — 스플래시가
  /// 미리 받아 둔 경우가 그렇고, 거기서 notify 하면 배너가 그대로인데도 목록이
  /// 다시 그려진다.
  Future<void> _loadPromotedNotice() async {
    try {
      final notices = await _notices.fetchPromoted();
      final dismissed = await _noticePreferences.loadDismissedIds();
      if (_disposed) return;
      final before = promotedNotice;
      _promotedNotices = notices;
      _dismissedNoticeIds = dismissed;
      // 공지가 내려갔으면 배너도 걷어야 하므로, 빈 목록이어도 그대로 반영한다.
      if (promotedNotice?.id != before?.id) notifyListeners();
    } catch (e) {
      debugPrint('[Schedule] 배너 공지 조회 실패: $e');
    }
  }

  /// 띠배너 ✕ — 해당 공지를 닫음 처리하고 다음 안 닫은 배너가 있으면 이어서 보여준다.
  void dismissPromotedNotice() {
    final notice = promotedNotice;
    if (notice == null) return;
    _dismissedNoticeIds = {..._dismissedNoticeIds, notice.id};
    notifyListeners();
    unawaited(_noticePreferences.addDismissedId(notice.id));
  }

  /// 저장된 필터를 읽지 못했는지. true 면 디스크에 값이 살아 있을 수 있어
  /// 현재 화면 상태(기본값 '전체')로 덮어쓰면 안 된다. [_persistFilter] 가 막는다.
  bool _filterRestoreFailed = false;

  /// 마지막 사용 필터를 복원한 뒤 첫 캘린더를 조회한다.
  /// 저장값이 없으면(첫 실행) 기본값 그대로 '전체'.
  Future<void> _init() async {
    final saved =
        await _filterPreferences.load(FilterPreferenceRepository.scheduleKey);
    // 저장된 필터를 읽는 사이에 화면이 사라질 수 있다(콜드 스타트 딥링크로
    // 첫 화면이 곧바로 교체되는 경로). 그대로 진행하면 죽은 뷰모델이 조회를
    // 걸어 로딩만 켜 두고 끝나, 다음에 뜬 화면이 멈춘 스피너를 물려받는다.
    if (_disposed) return;
    _filterRestoreFailed = saved.readFailed;
    final json = saved.json;
    if (json != null) {
      final leagues = (json['leagues'] as List?)?.cast<String>();
      _leagues = leagues != null && leagues.isNotEmpty ? leagues : ['ALL'];
      _teamIds = (json['teamIds'] as List?)?.cast<int>() ?? const [];
      _teamSelected = (json['teamSelected'] as bool?) ?? false;
    }
    loadCalendar();
  }

  /// 현재 필터를 저장한다. 실패해도 조회는 계속되므로 기다리지 않는다.
  ///
  /// 복원에 실패한 상태에서는 저장하지 않는다 — 지금 화면은 저장값을 못 읽어
  /// 기본값('전체')으로 서 있을 뿐이라, 여기서 쓰면 디스크의 멀쩡한 필터를
  /// 지운다. 이 경우 사용자의 선택은 이번 세션에만 적용되고, 다음 실행에서
  /// 저장값을 읽는 데 성공하면 원래 필터로 돌아온다.
  void _persistFilter() {
    if (_filterRestoreFailed) {
      debugPrint('[Schedule] 필터 복원 실패 상태 — 저장 생략(기존 값 보존)');
      return;
    }
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

  CalendarWeekStart _weekStart = CalendarWeekStart.monday;

  /// 캘린더 시작 요일 설정. 마이페이지에서 바꾼 값을, 탭 전환으로 이 ViewModel이
  /// 새로 만들어질 때 캐시로 즉시 반영한다(스포방지 설정과 동일한 보장).
  CalendarWeekStart get weekStart => _weekStart;

  /// 저장된 캘린더 시작 요일 설정을 복원한다. 생성자에서 캐시로 이미 맞춘 값과 같으면 알리지 않는다.
  Future<void> _restoreWeekStart() async {
    final saved = await _weekStartPreferences.load();
    if (_disposed || saved == _weekStart) return;
    _weekStart = saved;
    notifyListeners();
  }

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

  /// 리그·팀 중 하나라도 '전체'가 아닌 값으로 필터링 중인지.
  /// 헤더 필터 버튼에 선택 표시(테두리)를 줄지 판단하는 데 쓴다.
  bool get hasActiveFilter =>
      !(_leagues.length == 1 && _leagues.first == 'ALL') ||
      _teamIds.isNotEmpty;

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
  ///
  /// 응원팀을 모르는 동안에는 아무것도 하지 않는다. 예전에는 그때도 토글이
  /// 넘어가 `_teamIds` 를 비우고 저장까지 했다 — 저장된 팀 필터가 '전체'로
  /// 덮어써지는 경로다. 헤더 아이콘은 응원팀이 있을 때만 그려지지만(그래서
  /// 보통은 닿지 않는다), 조회가 끝나기 전 첫 프레임이나 조회 실패 후
  /// 로컬 캐시까지 비었을 때는 [_preferredTeam] 이 null 인 채로 남는다.
  void toggleTeamSelected() {
    final preferredId = _preferredTeam?.id;
    if (preferredId == null) {
      debugPrint('[Schedule] 응원팀 미확정 — 팀 토글 무시');
      return;
    }
    _teamSelected = !_teamSelected;
    _teamIds = _teamSelected ? [preferredId] : const [];
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
    // 빈 목록은 '전체'로 취급한다. 이전 리그를 남겨두면 시트에서 리그를 전부
    // 해제한 의도가 무시돼 필터가 안 먹은 것처럼 보인다.
    _leagues = (leagues == null || leagues.isEmpty) ? const ['ALL'] : leagues;
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
    unawaited(HomeWidgetService.updateFilterState(
      hasFilter: hasActiveFilter,
      teamSelected: _teamSelected,
    ));
  }

  /// 날짜 피커에서 고른 날짜를 반영한다 — 그 달로 이동하고 칸을 강조한다.
  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    displayMonth = date; // 월이 다르면 정규화·통지·재조회한다.
    _notify(); // 같은 달이면 위에서 통지 안 됐을 수 있어 한 번 더.
  }

  /// 캘린더 조회 세대. 새 조회가 시작될 때마다 올라간다.
  ///
  /// 월 이동·필터 변경·백그라운드 복귀가 겹치면 조회가 여러 개 동시에 뜬다.
  /// 응답이 돌아온 시점에 자기 세대가 최신이 아니면 결과를 버려, 늦게 도착한
  /// 옛 조회가 최신 화면을 덮어쓰거나 로딩을 먼저 내려버리는 걸 막는다.
  int _calendarRequestId = 0;

  /// 현재 표시 월의 경기 캘린더를 불러온다.
  ///
  /// `/api/mobile/schedules/calendar` 한 번으로 날짜별 칩 데이터까지 받는다.
  /// [forceRefresh] 면 리포지토리 캐시·진행 중 요청을 건너뛰고 새로 받는다.
  Future<void> loadCalendar({bool forceRefresh = false}) async {
    final requestId = ++_calendarRequestId;
    // 조회 시작 시점의 조건을 고정해 둔다. 응답을 기다리는 동안 필터가 바뀌어도
    // 이 조회의 결과·위젯 갱신은 자기가 요청한 조건 기준이어야 한다.
    final month = _displayMonth;
    final leagues = _leagues;
    final teamIds = _teamIds;

    debugPrint('[Schedule] loadCalendar#$requestId 시작: $month '
        '(leagues=$leagues, teamIds=$teamIds)');
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final days = await _repository.fetchCalendar(
        month,
        leagues: leagues,
        teamIds: teamIds,
        forceRefresh: forceRefresh,
      );
      if (requestId != _calendarRequestId) {
        debugPrint('[Schedule] loadCalendar#$requestId 결과 폐기 (더 최신 조회 있음)');
        return;
      }
      _matchesByDay = {
        for (final day in days) day.date.day: day.matches,
      };
      final total =
          _matchesByDay.values.fold<int>(0, (sum, l) => sum + l.length);
      debugPrint('[Schedule] 완료#$requestId: ${_matchesByDay.length}일, 총 $total경기');
      // 홈 화면 위젯에 최신 캘린더 데이터 전달 (필터 포함)
      unawaited(HomeWidgetService.updateCalendar(
        month: month,
        matchesByDay: _matchesByDay,
        leagues: leagues,
        teamIds: teamIds,
      ));
    } catch (e, st) {
      if (requestId != _calendarRequestId) {
        debugPrint('[Schedule] loadCalendar#$requestId 에러 무시 (더 최신 조회 있음): $e');
        return;
      }
      _error = appStrings?.scheduleLoadFailed ?? 'Failed to load schedule';
      _matchesByDay = const {};
      debugPrint('[Schedule] loadCalendar#$requestId 에러: $e');
      debugPrint('$st');
    } finally {
      // 최신 조회만 로딩을 내린다. 구버전이 내리면 아직 진행 중인 조회가 있는데도
      // 로딩이 꺼져 빈 화면이 잠깐 보인다.
      if (requestId == _calendarRequestId) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// 응원 팀을 불러온다.
  ///
  /// 로그인 회원은 서버(`/api/auth/me`)의 `favoriteTeamId` 를 기준으로 팀을
  /// 매칭하고, 비로그인 등 실패 시 로컬 캐시로 폴백한다.
  Future<void> _loadPreferredTeam() async {
    try {
      // teamId 를 알기 전에도 팀 목록은 미리 받아둔다 — fetchMe 와 겹쳐서
      // 왕복 한 번을 아낀다. (teamId 가 null 이면 결과는 버려진다.)
      final teamsFuture = _onboarding.fetchTeams();
      final me = await _auth.fetchMe();
      final teamId = me.favoriteTeamId;
      final teams = await teamsFuture;
      Team? team;
      if (teamId != null) {
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
