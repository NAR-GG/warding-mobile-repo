import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';

/// 스포방지(카드 스코어 블러) on/off 를 기기에 로컬 저장한다.
///
/// 경기 리스트와 경기 일정의 날짜별 경기 리스트가 같은 값을 공유한다.
/// 한 화면에서 끄면 다른 화면과 앱 재시작 이후에도 꺼진 상태가 유지된다.
/// 민감 정보는 아니지만 기존 관례대로 [FlutterSecureStorage] 를 재사용한다.
class SpoilerPreferenceRepository {
  SpoilerPreferenceRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? secureStorage;

  static final SpoilerPreferenceRepository instance =
      SpoilerPreferenceRepository();

  static const String _key = 'spoiler_prevention_enabled';

  final FlutterSecureStorage _storage;

  /// 저장값을 읽기 전까지 각 ViewModel 이 매번 스토리지를 때리지 않도록 캐싱한다.
  /// 화면 전환마다 ViewModel 이 새로 만들어지므로 첫 프레임 깜빡임도 줄인다.
  bool? _cached;

  /// 마지막으로 읽어둔 값. 아직 한 번도 로드 전이면 null.
  /// ViewModel 이 초기값을 동기적으로 정할 때 쓴다.
  bool? get cachedValue => _cached;

  /// 저장된 값을 읽는다. 저장된 적 없거나 손상됐으면 기본값 true(스포방지 on).
  Future<bool> load() async {
    if (_cached != null) return _cached!;
    try {
      final raw = await _storage.read(key: _key);
      _cached = raw == null || raw.isEmpty ? true : raw == 'true';
    } catch (e) {
      // 플랫폼 채널 미지원(테스트 등) 포함 — 기본값으로 동작만 시킨다.
      debugPrint('[SpoilerPreference] 복원 실패: $e');
      _cached = true;
    }
    return _cached!;
  }

  /// 값을 저장한다. 실패해도 화면 동작은 막지 않는다.
  Future<void> save(bool value) async {
    _cached = value;
    try {
      await _storage.write(key: _key, value: value ? 'true' : 'false');
    } catch (e) {
      debugPrint('[SpoilerPreference] 저장 실패: $e');
    }
  }
}
