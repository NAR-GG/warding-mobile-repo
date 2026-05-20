import 'package:flutter/foundation.dart';

/// 경기 일정 화면 ViewModel.
///
/// 현재 표시 중인 '월'을 들고 있다. 월간 캘린더·경기 목록 로직이
/// 추가되면 여기에 함께 둔다.
class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel({DateTime? initialMonth})
    : _displayMonth = _monthOf(initialMonth ?? DateTime.now());

  DateTime _displayMonth;

  /// 현재 표시 중인 월 (1일 0시로 정규화된 DateTime).
  DateTime get displayMonth => _displayMonth;

  /// 헤더에 표시할 'yyyy.MM' 라벨. 예: '2026.04'.
  String get monthLabel =>
      '${_displayMonth.year}.${_displayMonth.month.toString().padLeft(2, '0')}';

  /// 표시 월을 변경한다. 캘린더에서 월 이동 시 호출한다.
  set displayMonth(DateTime month) {
    final normalized = _monthOf(month);
    if (normalized == _displayMonth) return;
    _displayMonth = normalized;
    notifyListeners();
  }

  /// 연·월만 남기고 1일 0시로 정규화한다.
  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);
}
