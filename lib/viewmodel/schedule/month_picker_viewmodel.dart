import 'package:flutter/foundation.dart';

import '../../repository/schedule/schedule_repository.dart';

/// 날짜 피커 모달 전용 ViewModel.
///
/// 메인 경기 일정 화면과 **독립된** '모달 안에서 둘러보는 월'을 들고,
/// 그 달의 경기 있는 날짜(달력 점)를 `/api/schedule/calendar` 로 조회한다.
/// 모달에서 화살표로 월을 넘겨도 메인 화면은 바뀌지 않는다 — 실제로
/// 날짜를 고를 때만 View 가 그 결과를 메인 화면에 반영한다.
class MonthPickerViewModel extends ChangeNotifier {
  MonthPickerViewModel({
    required DateTime initialMonth,
    String filterLeague = 'ALL',
    int? filterTeamId,
    ScheduleRepository? repository,
  }) : _month = DateTime(initialMonth.year, initialMonth.month),
       _filterLeague = filterLeague,
       _filterTeamId = filterTeamId,
       _repository = repository ?? ScheduleRepository.instance {
    loadCalendar();
  }

  final ScheduleRepository _repository;

  // 메인 화면과 같은 리그·팀 필터. 안 넘기면 repository 기본값('LCK')으로 조회돼
  // 본문 캘린더와 점 표시가 어긋난다 — 호출부가 반드시 메인 필터를 전달한다.
  final String _filterLeague;
  final int? _filterTeamId;
  bool _disposed = false;

  DateTime _month;

  /// 모달이 현재 보여주는 월 (1일 0시로 정규화).
  DateTime get month => _month;

  /// 헤더에 표시할 'yyyy.MM' 라벨. 예: '2025.12'.
  String get monthLabel =>
      '${_month.year}.${_month.month.toString().padLeft(2, '0')}';

  Set<int> _matchDays = const {};

  /// 현재 월에서 경기가 있는 '일(day)' 집합. 달력 마킹(점)용.
  Set<int> get matchDays => _matchDays;

  /// 월을 [delta] 만큼 이동하고 그 달의 경기 날짜를 다시 조회한다.
  /// DateTime 생성자가 12월 초과·0 이하 월을 연도까지 정규화한다.
  void shiftMonth(int delta) {
    _month = DateTime(_month.year, _month.month + delta);
    _matchDays = const {}; // 새 달 조회 전까지 점을 비운다.
    _notify();
    loadCalendar();
  }

  /// 현재 월의 경기 있는 날짜를 조회한다.
  Future<void> loadCalendar() async {
    try {
      final days = await _repository.fetchCalendar(
        _month,
        league: _filterLeague,
        teamId: _filterTeamId,
      );
      _matchDays = {for (final day in days) day.date.day};
    } catch (e) {
      debugPrint('[MonthPicker] loadCalendar 에러: $e');
      _matchDays = const {};
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
}
