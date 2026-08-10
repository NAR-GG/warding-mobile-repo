import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../model/quiet_hours.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/notification/quiet_hours_repository.dart';

/// 마이페이지 알림 잠자기 섹션 ViewModel.
class QuietHoursViewModel extends ChangeNotifier {
  QuietHoursViewModel({QuietHoursRepository? repository})
      : _repo = repository ?? QuietHoursRepository.instance {
    load();
  }

  final QuietHoursRepository _repo;
  bool _disposed = false;

  QuietHours _settings = QuietHours.initial;
  QuietHours get settings => _settings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 저장 중이면 토글·시각 탭을 막는다. 연타로 요청이 겹치는 걸 방지한다.
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// 저장 실패 문구. 안내 문구 아래에 덧붙여 노출하고, 다음 저장 시도 때 비운다.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 로그인(JWT 보유) 여부. 비회원이면 섹션을 통째로 숨긴다.
  bool _loggedIn = true;
  bool get loggedIn => _loggedIn;

  Future<void> load() async {
    _isLoading = true;
    _notify();
    try {
      // 비회원이면 `/me` API 를 호출하지 않고 조용히 섹션을 숨긴다.
      final jwt = await AuthService.instance.jwt;
      if (jwt == null || jwt.isEmpty) {
        _loggedIn = false;
        return;
      }
      _loggedIn = true;
      _settings = await _repo.fetch();
    } catch (e, st) {
      debugPrint('[QuietHours] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> setEnabled(bool enabled) => _save(_settings.copyWith(enabled: enabled));

  Future<void> setStart(TimeOfDay start) => _save(_settings.copyWith(start: start));

  Future<void> setEnd(TimeOfDay end) => _save(_settings.copyWith(end: end));

  /// 낙관적 반영 후 저장한다. 실패하면 이전 값으로 되돌린다 —
  /// 화면이 저장된 것처럼 남아 있으면 유저가 잠자기가 켜졌다고 착각한다.
  Future<void> _save(QuietHours next) async {
    if (_isSaving) return;
    // 시작 == 종료는 서버가 400 을 주므로 왕복 전에 막고 문구를 띄운다.
    if (next.enabled && next.isSameTime) {
      _errorMessage = appStrings?.quietHoursSameTimeError ??
          '시작과 종료가 같으면 안 됩니다. 다른 시간을 골라주세요.';
      _notify();
      return;
    }
    final previous = _settings;
    _settings = next;
    _isSaving = true;
    _errorMessage = null;
    _notify();
    try {
      _settings = await _repo.update(next);
    } catch (e, st) {
      _settings = previous;
      _errorMessage = appStrings?.quietHoursSaveFailed ??
          'Failed to save quiet hours';
      debugPrint('[QuietHours] save 에러: $e\n$st');
    } finally {
      _isSaving = false;
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
}
