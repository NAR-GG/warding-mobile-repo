import 'package:flutter/foundation.dart';

import '../../model/schedule_match.dart';
import '../../repository/schedule/schedule_repository.dart';

/// 경기 일정 화면 ViewModel.
///
/// 현재 표시 중인 '월'과, 그 달의 경기 캘린더(날짜별 경기 목록)를 들고 있다.
class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel({DateTime? initialMonth, ScheduleRepository? repository})
    : _displayMonth = _monthOf(initialMonth ?? DateTime.now()),
      _repository = repository ?? ScheduleRepository.instance {
    loadCalendar();
  }

  final ScheduleRepository _repository;

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
