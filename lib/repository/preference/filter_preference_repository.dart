import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 화면별 경기 필터 선택값을 기기에 로컬 저장한다.
///
/// 경기 일정(캘린더)과 경기 리스트가 각자 키로 마지막 필터를 저장하고,
/// 앱 재시작 시 그대로 복원한다. 화면마다 필터 구조가 달라
/// 저장 형태는 각 ViewModel 이 정하고 여기는 JSON 통째로만 다룬다.
/// 민감 정보는 아니지만 기존 관례대로 [FlutterSecureStorage] 를 재사용한다.
class FilterPreferenceRepository {
  FilterPreferenceRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final FilterPreferenceRepository instance =
      FilterPreferenceRepository();

  /// 경기 일정(캘린더) 화면 필터 키.
  static const String scheduleKey = 'schedule_filter';

  /// 경기 리스트 화면 필터 키.
  static const String matchListKey = 'match_list_filter';

  final FlutterSecureStorage _storage;

  /// [key] 에 필터 JSON 을 저장한다.
  Future<void> save(String key, Map<String, dynamic> json) async {
    try {
      await _storage.write(key: key, value: jsonEncode(json));
    } catch (e) {
      // 저장 실패는 기능(조회) 자체를 막지 않는다.
      debugPrint('[FilterPreference] 저장 실패($key): $e');
    }
  }

  /// [key] 의 저장값을 읽는다. 없거나 손상됐으면 null.
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      // 파싱 실패·플랫폼 채널 미지원(테스트 등) 모두 '저장값 없음' 취급.
      debugPrint('[FilterPreference] 복원 실패($key): $e');
      return null;
    }
  }
}
