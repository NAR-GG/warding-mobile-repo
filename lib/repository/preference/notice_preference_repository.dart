import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../config/secure_storage.dart';

/// 캘린더 상단 띠배너에서 ✕로 닫은 공지 id 목록을 기기에 저장한다.
///
/// 배너가 여러 개 발행될 수 있어 목록으로 저장하고, 앱은 "안 닫은 첫 배너"를 띄운다.
/// [TeamPreferenceRepository]와 같은 이유로 이미 설치된
/// [FlutterSecureStorage]를 재사용한다.
class NoticePreferenceRepository {
  NoticePreferenceRepository._();
  static final NoticePreferenceRepository instance =
      NoticePreferenceRepository._();

  static const _key = 'dismissed_notice_ids';

  Set<int>? _cached;

  /// 마지막으로 읽어둔 값. 아직 한 번도 로드 전이면 null.
  ///
  /// ViewModel 이 배너 표시 여부를 **첫 프레임에** 정하는 데 쓴다. 이 값 없이
  /// [loadDismissedIds] 를 기다리면, 이미 닫은 배너가 한 프레임 보였다가
  /// 사라지며 캘린더를 두 번 밀어낸다.
  ///
  /// 내부 Set 을 그대로 넘기지 않는다 — 호출부가 그걸 고치면 저장된 적 없는
  /// id 가 캐시에 섞여, 다음 [loadDismissedIds] 가 storage 와 다른 답을 준다.
  Set<int>? get cachedValue {
    final cached = _cached;
    return cached == null ? null : {...cached};
  }

  /// 닫은 공지 id를 목록에 추가한다.
  Future<void> addDismissedId(int noticeId) async {
    final ids = await loadDismissedIds();
    ids.add(noticeId);
    _cached = ids;
    try {
      await writeWithDuplicateRecovery(
        key: _key,
        value: jsonEncode(ids.toList()),
      );
    } catch (e) {
      debugPrint('[NoticePreference] 저장 실패: $e');
    }
  }

  /// 닫은 공지 id 목록. 없거나 손상됐으면 빈 셋.
  Future<Set<int>> loadDismissedIds() async {
    final cached = _cached;
    if (cached != null) return {...cached};
    final raw = await readOrNull(_key);
    if (raw == null || raw.isEmpty) return _cached = {};
    try {
      return _cached = {
        for (final id in jsonDecode(raw) as List) (id as num).toInt(),
      };
    } catch (e) {
      debugPrint('[NoticePreference] 저장값 파싱 실패: $e');
      return _cached = {};
    }
  }

  /// 테스트 전용 — 인메모리 캐시를 비워 다음 읽기가 storage 를 다시 보게 한다.
  @visibleForTesting
  void resetCacheForTesting() => _cached = null;
}
