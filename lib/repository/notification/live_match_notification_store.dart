import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';

import '../../model/live_match_notification.dart';
import '../fcm/fcm_notification_types.dart';

/// 수신한 '라이브 경기' 푸시(세트 시작/종료/경기 이벤트)를 기기에 로컬 저장한다.
///
/// 솔랭 알림과 분리된 별도 저장소다([SoloRankNotificationStore]와 구조 동일).
/// 서버 알림 기록 API가 없어 포그라운드/백그라운드에서 받은 푸시를 여기에 쌓는다.
/// 이미 설치된 [FlutterSecureStorage] 를 재사용한다.
class LiveMatchNotificationStore {
  LiveMatchNotificationStore._();
  static final LiveMatchNotificationStore instance =
      LiveMatchNotificationStore._();

  static const _key = 'live_match_notifications';

  /// 피드에 보관하는 최대 개수(최신 우선).
  static const _maxItems = 50;

  final _storage = secureStorage;

  /// 저장된 알림을 최신순으로 읽는다.
  Future<List<LiveMatchNotification>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              LiveMatchNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[LiveMatchStore] 파싱 실패: $e');
      return const [];
    }
  }

  /// 알림 한 건을 맨 앞에 추가한다. 중복(dedupeKey)은 무시하고, 최대 개수를 넘으면 자른다.
  Future<void> add(LiveMatchNotification notification) async {
    final current = List<LiveMatchNotification>.from(await loadAll());
    if (current.any((n) => n.dedupeKey == notification.dedupeKey)) return;
    current.insert(0, notification);
    final trimmed =
        current.length > _maxItems ? current.sublist(0, _maxItems) : current;
    await _save(trimmed);
  }

  /// FCM data 페이로드로부터 저장한다(타입이 라이브 경기일 때만).
  /// 제목/본문은 notification 페이로드에서 온 값을 [title]/[body] 로 넘길 수 있다.
  Future<void> addFromFcmData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) async {
    if (!FcmNotificationType.isLiveMatch(data['type'])) return;
    await add(LiveMatchNotification.fromFcmData(
      data,
      title: title,
      body: body,
    ));
  }

  Future<void> _save(List<LiveMatchNotification> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: encoded);
  }
}
