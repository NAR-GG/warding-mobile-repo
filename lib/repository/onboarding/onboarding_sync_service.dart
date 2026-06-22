import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../preference/onboarding_preference_repository.dart';
import 'onboarding_repository.dart';

/// 로그인 직후 비회원 시절 로컬에 저장된 온보딩 선택값을 서버로 1회 동기화한다.
class OnboardingSyncService {
  OnboardingSyncService({
    OnboardingRepository? repository,
    OnboardingPreferenceRepository? preferences,
  })  : _repository = repository ?? OnboardingRepository.instance,
        _preferences = preferences ?? OnboardingPreferenceRepository.instance;

  static final OnboardingSyncService instance = OnboardingSyncService();

  final OnboardingRepository _repository;
  final OnboardingPreferenceRepository _preferences;

  /// 로그인 결과를 받아 최종 onboarded 여부를 반환한다.
  ///
  /// - 서버가 이미 onboarded면 남은 로컬 selection 을 지우고 true.
  /// - 미onboarded인데 로컬 selection 이 있으면 서버로 전송 후 지우고 true.
  ///   전송 실패 시 로컬을 보존하고 false (다음 로그인에 재시도).
  /// - 로컬 selection 이 없으면 false.
  Future<bool> syncOnLogin(AuthResult result) async {
    if (result.isOnboarded) {
      await _preferences.clear();
      return true;
    }

    final selection = await _preferences.loadSelection();
    if (selection == null) return false;

    try {
      await _repository.completeOnboarding(
        favoriteLeagueName: selection.leagueName,
        favoriteTeamId: selection.teamId,
        favoritePlayerIds: selection.playerIds,
        jwt: result.jwt,
      );
    } catch (e) {
      debugPrint('[OnboardingSync] 로그인 동기화 실패: $e');
      return false;
    }

    await _preferences.clear();
    return true;
  }
}
