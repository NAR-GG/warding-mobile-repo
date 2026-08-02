import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/secure_storage.dart';

import '../../model/solo_rank_notification.dart';
import '../fcm/fcm_notification_types.dart';

/// 수신한 '선수 솔랭 시작' 푸시를 기기에 로컬 저장한다.
///
/// 서버 알림 기록 API가 없어, 포그라운드/백그라운드에서 받은 푸시를
/// 여기에 쌓아 마이구독 피드([SubscriptionFeedViewModel])에서 읽는다.
/// 선호 팀과 동일하게 이미 설치된 [FlutterSecureStorage] 를 재사용한다.
class SoloRankNotificationStore {
  SoloRankNotificationStore._();
  static final SoloRankNotificationStore instance =
      SoloRankNotificationStore._();

  static const _key = 'solo_rank_notifications';

  /// 피드에 보관하는 최대 개수(최신 우선).
  static const _maxItems = 50;

  final _storage = secureStorage;

  /// 저장된 알림을 최신순으로 읽는다.
  Future<List<SoloRankNotification>> loadAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              SoloRankNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SoloRankStore] 파싱 실패: $e');
      return const [];
    }
  }

  /// 알림 한 건을 맨 앞에 추가한다. 같은 게임(중복)은 무시하고, 최대 개수를 넘으면 자른다.
  Future<void> add(SoloRankNotification notification) async {
    final current = List<SoloRankNotification>.from(await loadAll());
    if (current.any((n) => n.dedupeKey == notification.dedupeKey)) return;
    current.insert(0, notification);
    final trimmed =
        current.length > _maxItems ? current.sublist(0, _maxItems) : current;
    await _save(trimmed);
  }

  /// FCM data 페이로드로부터 저장한다(타입이 솔랭일 때만).
  Future<void> addFromFcmData(Map<String, dynamic> data) async {
    if (data['type'] != FcmNotificationType.playerSoloRankStarted) return;
    await add(SoloRankNotification.fromFcmData(data));
  }

  Future<void> _save(List<SoloRankNotification> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: encoded);
  }
}
