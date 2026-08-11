import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';
import '../../model/calendar_week_start.dart';

/// 캘린더 시작 요일(월요일/일요일) 설정을 기기에 로컬 저장한다.
///
/// 경기 일정 화면의 캘린더·월 선택 시트, 홈 화면 위젯이 같은 값을 공유한다.
/// 민감 정보는 아니지만 기존 관례대로 [FlutterSecureStorage] 를 재사용한다.
class CalendarWeekStartPreferenceRepository {
  CalendarWeekStartPreferenceRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? secureStorage;

  static final CalendarWeekStartPreferenceRepository instance =
      CalendarWeekStartPreferenceRepository();

  static const String _key = 'calendar_week_start';

  final FlutterSecureStorage _storage;

  /// 저장값을 읽기 전까지 각 ViewModel 이 매번 스토리지를 때리지 않도록 캐싱한다.
  /// 화면 전환마다 ViewModel 이 새로 만들어지므로 첫 프레임 깜빡임도 줄인다.
  CalendarWeekStart? _cached;

  /// 마지막으로 읽어둔 값. 아직 한 번도 로드 전이면 null.
  CalendarWeekStart? get cachedValue => _cached;

  /// 저장된 값을 읽는다. 저장된 적 없거나 손상됐으면 기본값 monday.
  Future<CalendarWeekStart> load() async {
    if (_cached != null) return _cached!;
    try {
      final raw = await _storage.read(key: _key);
      _cached = CalendarWeekStart.fromStorageValue(raw);
    } catch (e) {
      debugPrint('[CalendarWeekStartPreference] 복원 실패: $e');
      _cached = CalendarWeekStart.monday;
    }
    return _cached!;
  }

  /// 값을 저장한다. 실패해도 화면 동작은 막지 않는다.
  Future<void> save(CalendarWeekStart value) async {
    _cached = value;
    try {
      await _storage.write(key: _key, value: value.storageValue);
    } catch (e) {
      debugPrint('[CalendarWeekStartPreference] 저장 실패: $e');
    }
  }
}
