import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/calendar_week_start.dart';
import '../../repository/preference/calendar_week_start_preference_repository.dart';
import '../../util/home_widget_service.dart';

/// 마이페이지 — 캘린더 시작 요일 설정 ViewModel.
///
/// 기기 로컬 설정이라 로그인 여부와 무관하게 동작한다(QuietHours와 다른 점).
class CalendarWeekStartViewModel extends ChangeNotifier {
  CalendarWeekStartViewModel({CalendarWeekStartPreferenceRepository? repository})
      : _repository = repository ?? CalendarWeekStartPreferenceRepository.instance {
    // 이미 읽어둔 값이 있으면 첫 프레임부터 그 상태로 그린다.
    _weekStart = _repository.cachedValue ?? CalendarWeekStart.monday;
    _restore();
  }

  final CalendarWeekStartPreferenceRepository _repository;

  bool _disposed = false;

  CalendarWeekStart _weekStart = CalendarWeekStart.monday;
  CalendarWeekStart get weekStart => _weekStart;

  /// 저장된 값을 복원한다. 생성자에서 캐시로 이미 맞춘 값과 같으면 알리지 않는다.
  Future<void> _restore() async {
    final saved = await _repository.load();
    if (_disposed || saved == _weekStart) return;
    _weekStart = saved;
    notifyListeners();
  }

  void setWeekStart(CalendarWeekStart value) {
    if (_weekStart == value) return;
    _weekStart = value;
    notifyListeners();
    // 저장·위젯 갱신 실패해도 화면 선택은 그대로 반영되므로 기다리지 않는다.
    unawaited(_repository.save(value));
    unawaited(HomeWidgetService.updateWeekStart(value));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
