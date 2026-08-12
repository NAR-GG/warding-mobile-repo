import 'package:flutter/foundation.dart';

import '../../model/calendar_week_start.dart';
import '../../repository/preference/calendar_week_start_preference_repository.dart';
import '../../util/home_widget_service.dart';

/// 캘린더 설정 화면 ViewModel.
///
/// 캘린더 시작 요일을 들고 있다. 마이페이지의
/// [CalendarWeekStartViewModel] 과 달리 선택이 즉시 저장되지 않고,
/// '완료' 버튼([save])에서 한 번에 저장한다. 그래서 화면에 보이는 값
/// ([weekStart])과 저장된 값([_saved])을 따로 둔다.
class CalendarSettingViewModel extends ChangeNotifier {
  CalendarSettingViewModel({CalendarWeekStartPreferenceRepository? repository})
      : _repository =
            repository ?? CalendarWeekStartPreferenceRepository.instance {
    // 이미 읽어둔 값이 있으면 첫 프레임부터 그 상태로 그린다.
    final cached = _repository.cachedValue;
    if (cached != null) {
      _weekStart = cached;
      _saved = cached;
    }
    load();
  }

  final CalendarWeekStartPreferenceRepository _repository;
  bool _disposed = false;

  /// 화면에 보이는 값. 선택하면 여기만 바뀐다.
  CalendarWeekStart _weekStart = CalendarWeekStart.monday;
  CalendarWeekStart get weekStart => _weekStart;

  /// 마지막으로 저장된 값. 변경 여부 판단 기준선.
  CalendarWeekStart _saved = CalendarWeekStart.monday;

  /// 저장되지 않은 변경이 있는지. '완료' 버튼 활성 조건.
  bool get isDirty => _weekStart != _saved;

  /// 저장된 값을 불러온다.
  Future<void> load() async {
    final saved = await _repository.load();
    if (_disposed) return;
    // 불러오는 사이 유저가 선택했으면 그 값을 지킨다.
    if (isDirty) {
      _saved = saved;
      notifyListeners();
      return;
    }
    if (saved == _weekStart && saved == _saved) return;
    _weekStart = saved;
    _saved = saved;
    notifyListeners();
  }

  /// 시작 요일 선택. 저장은 [save] 에서 한다.
  void setWeekStart(CalendarWeekStart value) {
    if (_weekStart == value) return;
    _weekStart = value;
    notifyListeners();
  }

  /// 변경분을 저장하고 홈 위젯에도 반영한다.
  Future<void> save() async {
    if (!isDirty) return;
    final value = _weekStart;
    await _repository.save(value);
    await HomeWidgetService.updateWeekStart(value);
    if (_disposed) return;
    _saved = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
