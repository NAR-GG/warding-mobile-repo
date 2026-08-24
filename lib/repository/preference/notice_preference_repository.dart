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

  /// 저장값을 읽지 못했는지(Keychain 잠금 등). true 면 저장된 목록이 살아 있을 수
  /// 있어, 지금의 빈 목록으로 덮어쓰면 안 된다.
  ///
  /// 목록 전체를 통째로 다시 쓰는 구조라 이 구분이 없으면 한 번의 읽기 실패가
  /// 곧바로 "예전에 닫은 공지가 전부 되살아남"이 된다 — 읽기 실패로 빈 목록을
  /// 캐시하고, 유저가 배너 하나를 닫는 순간 그 빈 목록 + id 하나만 저장됐다.
  bool _readFailed = false;

  /// 닫은 공지 id를 목록에 추가한다.
  ///
  /// 저장된 목록을 못 읽은 상태면 저장을 건너뛴다. 이번 세션에는 캐시로 닫힌
  /// 상태가 유지되고, 다음 실행에서 읽기에 성공하면 원래 목록이 그대로 돌아온다.
  Future<void> addDismissedId(int noticeId) async {
    final ids = await loadDismissedIds();
    ids.add(noticeId);
    if (_readFailed) {
      // 캐시에 담지 않는다 — 담으면 [loadDismissedIds] 가 그 빈 목록 기반 캐시를
      // 계속 돌려줘, 잠금이 풀린 뒤에도 저장값을 영영 다시 읽지 않는다.
      // 이 배너는 다시 뜨겠지만, 저장된 목록이 날아가는 것보다 낫다.
      debugPrint('[NoticePreference] 읽기 실패 상태 — 저장 생략(기존 목록 보존)');
      return;
    }
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
  ///
  /// 못 읽은 경우에도 빈 셋을 돌려주지만(배너는 보이는 편이 안전하다)
  /// [_readFailed] 를 세워 [addDismissedId] 가 덮어쓰지 않게 한다.
  Future<Set<int>> loadDismissedIds() async {
    final cached = _cached;
    if (cached != null) return {...cached};
    final String? raw;
    try {
      raw = await readOrThrowIfUnavailable(_key);
      _readFailed = false;
    } catch (e) {
      // 잠금·플랫폼 채널 오류 등. 저장값이 없다는 증거가 아니다.
      debugPrint('[NoticePreference] 읽기 실패: $e');
      _readFailed = true;
      return {};
    }
    if (raw == null || raw.isEmpty) return _cached = {};
    try {
      return _cached = {
        for (final id in jsonDecode(raw) as List) (id as num).toInt(),
      };
    } catch (e) {
      // 읽기는 됐는데 내용이 깨졌다 — 되살릴 값이 없으니 덮어써도 된다.
      debugPrint('[NoticePreference] 저장값 파싱 실패: $e');
      return _cached = {};
    }
  }

  /// 테스트 전용 — 인메모리 캐시를 비워 다음 읽기가 storage 를 다시 보게 한다.
  @visibleForTesting
  void resetCacheForTesting() => _cached = null;
}
