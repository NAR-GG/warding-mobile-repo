import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';

/// 필터 복원 결과 — '저장된 적 없음'과 '읽지 못함'을 구분한다.
///
/// 둘 다 [json] 이 null 이지만 의미가 정반대다. 저장된 적 없음은 기본값('전체')
/// 으로 시작하는 게 맞고, 읽지 못함은 **디스크에 값이 살아 있을 수 있다**.
/// 후자를 기본값으로 뭉개고 그 상태에서 저장까지 하면 멀쩡한 필터가 영구히
/// 날아간다 — 실제로 "필터가 간헐적으로 전체로 풀린다"의 원인이었다.
class FilterPreferenceResult {
  const FilterPreferenceResult._(this.json, this.readFailed);

  /// 정상적으로 읽었다 — [json] 이 null 이면 '저장된 적 없음'이 확실하다.
  const FilterPreferenceResult.loaded(Map<String, dynamic>? json)
      : this._(json, false);

  /// 읽지 못했다. 저장값 유무는 알 수 없으므로 덮어쓰면 안 된다.
  const FilterPreferenceResult.failed() : this._(null, true);

  /// 복원된 필터 JSON. 없거나 못 읽었으면 null.
  final Map<String, dynamic>? json;

  /// 읽기 자체가 실패했는지. true 면 [json] 의 null 을 '값 없음'으로 읽으면 안 된다.
  final bool readFailed;
}

/// 화면별 경기 필터 선택값을 기기에 로컬 저장한다.
///
/// 경기 일정(캘린더)과 경기 리스트가 각자 키로 마지막 필터를 저장하고,
/// 앱 재시작 시 그대로 복원한다. 화면마다 필터 구조가 달라
/// 저장 형태는 각 ViewModel 이 정하고 여기는 JSON 통째로만 다룬다.
/// 민감 정보는 아니지만 기존 관례대로 [FlutterSecureStorage] 를 재사용한다.
///
/// TODO(다음 스토어 릴리즈): `shared_preferences` 직접 의존을 추가해 필터·선호팀
/// 등 비민감 값을 옮긴다. Keychain 은 잠금 중 읽기 실패(-25308)·접근성
/// 마이그레이션 같은 함정이 있어 이 값들이 떠안을 이유가 없다. 네이티브 플러그인
/// 추가라 Shorebird 패치로는 못 나가서 재제출 때 묶는다.
class FilterPreferenceRepository {
  FilterPreferenceRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? secureStorage;

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

  /// [key] 의 저장값을 읽는다.
  ///
  /// 읽기 실패와 '저장된 적 없음'을 구분해 돌려준다 — 자세한 이유는
  /// [FilterPreferenceResult] 참고. 호출부는 [FilterPreferenceResult.readFailed]
  /// 가 true 면 기본값으로 되돌리지 말고, 저장도 하지 말아야 한다.
  Future<FilterPreferenceResult> load(String key) async {
    final String? raw;
    try {
      raw = await _storage.read(key: key);
    } catch (e) {
      // Keychain 잠금(-25308)·플랫폼 채널 미지원(테스트 등). 저장값이 없다는
      // 증거가 아니므로 '못 읽었다'로 올린다.
      debugPrint('[FilterPreference] 읽기 실패($key): $e');
      return const FilterPreferenceResult.failed();
    }
    if (raw == null || raw.isEmpty) {
      return const FilterPreferenceResult.loaded(null);
    }
    try {
      return FilterPreferenceResult.loaded(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // 읽기는 됐는데 내용이 깨졌다 — 되살릴 값이 없으니 덮어써도 된다.
      debugPrint('[FilterPreference] 파싱 실패($key): $e');
      return const FilterPreferenceResult.loaded(null);
    }
  }
}
