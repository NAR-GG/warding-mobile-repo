import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// 경기 예약(알림) 구독 API (`/api/mobile/me/match-subscriptions`).
///
/// 인증이 필요하다. 목록 조회 결과는 세션 동안 메모리에 캐시해 카드마다
/// 중복 조회하지 않고, 구독/해제 시 캐시를 낙관적으로 갱신한다.
class MatchSubscriptionRepository {
  MatchSubscriptionRepository._();
  static final MatchSubscriptionRepository instance =
      MatchSubscriptionRepository._();

  final AuthService _auth = AuthService.instance;

  Set<String>? _cache;
  Future<Set<String>>? _inFlight;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 구독 중인 경기 ID 목록을 조회한다. [forceRefresh] 가 아니면 캐시를 재사용한다.
  Future<Set<String>> subscribedMatchIds({bool forceRefresh = false}) {
    final cached = _cache;
    if (!forceRefresh && cached != null) return Future.value(cached);
    return _inFlight ??= _fetchAndCache();
  }

  Future<Set<String>> _fetchAndCache() async {
    try {
      final ids = await _fetchSubscribedMatchIds();
      _cache = ids;
      return ids;
    } finally {
      _inFlight = null;
    }
  }

  Future<Set<String>> _fetchSubscribedMatchIds() async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.matchSubscriptionsUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[MatchSubscription] 목록 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('경기 구독 목록 조회 실패 (${response.statusCode})');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => e.toString()).toSet();
  }

  /// 경기를 구독(예약)한다. 이미 구독 중이면 멱등하게 통과한다.
  /// 알림 종류별 토글(세트 시작/종료·라이브 이벤트)을 함께 보낸다.
  Future<void> subscribeMatch(
    String matchId, {
    bool setStartEnabled = true,
    bool setEndEnabled = true,
    bool liveEventEnabled = true,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.matchSubscriptionsUrl),
        headers: _headers(token),
        body: jsonEncode({
          'matchId': matchId,
          'setStartEnabled': setStartEnabled,
          'setEndEnabled': setEndEnabled,
          'liveEventEnabled': liveEventEnabled,
        }),
      ),
    );
    debugPrint('[MatchSubscription] 구독 → $matchId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postMatchAlarm',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.matchSubscriptionsUrl, 'statusCode': response.statusCode, 'matchId': matchId},
      );
      throw Exception('경기 구독 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'postMatchAlarm', extra: {'matchId': matchId});
    _cache = {...?_cache, matchId};
  }

  /// 경기 구독을 해제한다.
  Future<void> unsubscribeMatch(String matchId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.matchSubscriptionUrl(matchId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[MatchSubscription] 해제 → $matchId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'deleteMatchAlarm',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.matchSubscriptionUrl(matchId), 'statusCode': response.statusCode, 'matchId': matchId},
      );
      throw Exception('경기 구독 해제 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'deleteMatchAlarm', extra: {'matchId': matchId});
    final cached = _cache;
    if (cached != null) _cache = {...cached}..remove(matchId);
  }
}
