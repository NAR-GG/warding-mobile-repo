import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  final _storage = secureStorage;

  /// 닫은 공지 id를 목록에 추가한다.
  Future<void> addDismissedId(int noticeId) async {
    final ids = await loadDismissedIds()..add(noticeId);
    await _storage.write(key: _key, value: jsonEncode(ids.toList()));
  }

  /// 닫은 공지 id 목록. 없거나 손상됐으면 빈 셋.
  Future<Set<int>> loadDismissedIds() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return {};
    try {
      return {for (final id in jsonDecode(raw) as List) (id as num).toInt()};
    } catch (e) {
      debugPrint('[NoticePreference] 저장값 파싱 실패: $e');
      return {};
    }
  }
}
