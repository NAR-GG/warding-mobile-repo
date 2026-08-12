import 'package:flutter/foundation.dart';

import '../../repository/preference/spoiler_preference_repository.dart';

/// 경기리스트 설정 화면 ViewModel.
///
/// 스포 방지 카드 on/off 를 들고 있다. 경기 리스트·경기 일정 화면과 달리
/// 토글이 즉시 저장되지 않고, '완료' 버튼([save])에서 한 번에 저장한다.
/// 그래서 화면에 보이는 값([spoilerEnabled])과 저장된 값([_saved])을 따로 둔다.
class MatchListSettingViewModel extends ChangeNotifier {
  MatchListSettingViewModel({SpoilerPreferenceRepository? spoilerPreferences})
      : _spoilerPreferences =
            spoilerPreferences ?? SpoilerPreferenceRepository.instance {
    // 캐시가 있으면 첫 프레임부터 올바른 값으로 그린다.
    final cached = _spoilerPreferences.cachedValue;
    if (cached != null) {
      _spoilerEnabled = cached;
      _saved = cached;
    }
    load();
  }

  final SpoilerPreferenceRepository _spoilerPreferences;
  bool _disposed = false;

  /// 화면에 보이는 값. 토글하면 여기만 바뀐다.
  bool _spoilerEnabled = true;
  bool get spoilerEnabled => _spoilerEnabled;

  /// 마지막으로 저장된 값. 변경 여부 판단 기준선.
  bool _saved = true;

  /// 저장되지 않은 변경이 있는지. '완료' 버튼 활성 조건.
  bool get isDirty => _spoilerEnabled != _saved;

  /// 저장된 값을 불러온다.
  Future<void> load() async {
    final saved = await _spoilerPreferences.load();
    // 불러오는 사이 유저가 토글했으면 그 값을 지킨다.
    if (isDirty) {
      _saved = saved;
      _notify();
      return;
    }
    if (saved == _spoilerEnabled && saved == _saved) return;
    _spoilerEnabled = saved;
    _saved = saved;
    _notify();
  }

  /// 스포 방지 카드 토글. 저장은 [save] 에서 한다.
  void setSpoilerEnabled(bool value) {
    if (_spoilerEnabled == value) return;
    _spoilerEnabled = value;
    _notify();
  }

  /// 변경분을 저장한다.
  Future<void> save() async {
    if (!isDirty) return;
    final value = _spoilerEnabled;
    await _spoilerPreferences.save(value);
    _saved = value;
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
