import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';

import '../../model/onboarding_selection.dart';

/// 비회원 온보딩 선택값을 기기에 로컬 저장한다.
///
/// 로그인 시 [OnboardingSyncService] 가 읽어 서버로 1회 동기화한 뒤 지운다.
/// 헤더가 읽는 전체 팀 캐시([TeamPreferenceRepository])와 책임을 분리한다.
/// 민감 정보는 아니지만 이미 설치된 [FlutterSecureStorage] 를 재사용한다.
class OnboardingPreferenceRepository {
  OnboardingPreferenceRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? secureStorage;

  static final OnboardingPreferenceRepository instance =
      OnboardingPreferenceRepository();

  static const _key = 'onboarding_selection';

  final FlutterSecureStorage _storage;

  /// 온보딩 선택값을 저장한다. 실패해도 온보딩 진행은 막지 않는다.
  Future<void> saveSelection(OnboardingSelection selection) async {
    try {
      await writeWithDuplicateRecovery(
        key: _key,
        value: jsonEncode(selection.toJson()),
        storage: _storage,
      );
    } catch (e) {
      debugPrint('[OnboardingPreference] 저장 실패: $e');
    }
  }

  /// 저장된 선택값을 읽는다. 없거나 손상됐으면 null.
  Future<OnboardingSelection?> loadSelection() async {
    final raw = await readOrNull(_key, storage: _storage);
    if (raw == null || raw.isEmpty) return null;
    try {
      return OnboardingSelection.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[OnboardingPreference] 저장값 파싱 실패: $e');
      return null;
    }
  }

  /// 저장된 선택값을 지운다 (동기화 완료·온보딩 건너뛰기 시).
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('[OnboardingPreference] 삭제 실패: $e');
    }
  }
}
