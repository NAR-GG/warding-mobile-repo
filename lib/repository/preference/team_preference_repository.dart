import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';

import '../../model/team.dart';

/// 비회원 선호 팀을 기기에 로컬 저장한다.
///
/// 온보딩에서 고른 팀을 저장하고, 경기 일정 헤더 등에서 다시 읽는다.
/// 선호 팀은 민감 정보가 아니라 원래는 SharedPreferences 가 맞지만,
/// 이미 설치된 [FlutterSecureStorage] 를 재사용한다(패키지 추가 불필요).
/// 회원의 서버 저장(`POST /api/auth/onboarding`)은 추후 별도 연동한다.
class TeamPreferenceRepository {
  TeamPreferenceRepository._();
  static final TeamPreferenceRepository instance = TeamPreferenceRepository._();

  static const _key = 'preferred_team';

  final _storage = secureStorage;

  /// 선호 팀을 저장한다. 실패해도 화면 동작은 막지 않는다.
  Future<void> savePreferredTeam(Team team) async {
    try {
      await writeWithDuplicateRecovery(
        key: _key,
        value: jsonEncode(team.toJson()),
      );
    } catch (e) {
      debugPrint('[TeamPreference] 저장 실패: $e');
    }
  }

  /// 저장된 선호 팀을 읽는다. 없거나 손상됐으면 null.
  ///
  /// 선호 팀은 못 읽어도 '없음'으로 굴러가면 되는 값이라 잠금 실패도 null 로
  /// 접는다. 예전엔 잠금 중 백그라운드 호출에서 -25308 이 그대로 올라와
  /// 크래시로 잡혔다 (Sentry WARDING-APP-FLUTTER-6, 112명).
  Future<Team?> loadPreferredTeam() async {
    final raw = await readOrNull(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Team.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[TeamPreference] 저장값 파싱 실패: $e');
      return null;
    }
  }

  /// 저장된 선호 팀을 지운다 (온보딩 건너뛰기 시).
  Future<void> clearPreferredTeam() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('[TeamPreference] 삭제 실패: $e');
    }
  }
}
