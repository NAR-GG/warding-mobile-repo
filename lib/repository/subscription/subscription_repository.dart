import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/player_subscription.dart';
import '../../model/team_notification_subscription.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// 선수 구독·팀 알림 구독 관련 API (`/api/mobile/me/...`).
///
/// 모두 인증이 필요하다. [AuthService.authorizedRequest] 로 감싸 Access Token을
/// 싣고, 만료 시 Refresh Token으로 자동 갱신·재시도한다.
class SubscriptionRepository {
  SubscriptionRepository._();
  static final SubscriptionRepository instance = SubscriptionRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── 선수 구독 ────────────────────────────────────────────────────

  /// 진행 중인 구독 선수 요청 + 캐시. `/api/mobile/me/...` 인증 API 들이
  /// 응답이 150ms~4.3s 로 들쭉날쭉해서(2026-08-12 실측) 마이구독 탭을
  /// 오갈 때마다 그대로 체감됐다. 짧게 캐시해 잦은 재방문을 가려준다.
  /// [subscribePlayer]/[unsubscribePlayer]/[updatePlayerAlarm] 는 이 캐시를
  /// 지워 다음 조회가 최신 상태를 받게 한다.
  Future<List<PlayerSubscription>>? _subscribedInFlight;
  (DateTime, List<PlayerSubscription>)? _subscribedCache;
  static const Duration _subscribedCacheTtl = Duration(seconds: 30);

  void _invalidateSubscribedPlayersCache() => _subscribedCache = null;

  /// 테스트 전용 — 싱글턴 인스턴스에 남은 캐시를 지워 테스트 간 상태가
  /// 새지 않게 한다. [AuthService.resetJwtCacheForTesting] 와 같은 용도.
  @visibleForTesting
  void resetCacheForTesting() {
    _subscribedCache = null;
    _subscribedInFlight = null;
  }

  /// 내 구독 선수 목록을 조회한다.
  Future<List<PlayerSubscription>> fetchSubscribedPlayers() {
    final cached = _subscribedCache;
    if (cached != null &&
        DateTime.now().difference(cached.$1) < _subscribedCacheTtl) {
      debugPrint('[Subscription] 구독선수 cache hit');
      return Future.value(cached.$2);
    }
    final inFlight = _subscribedInFlight;
    if (inFlight != null) return inFlight;

    final request = _fetchSubscribedPlayers().then((list) {
      _subscribedCache = (DateTime.now(), list);
      return list;
    });
    unawaited(request.whenComplete(() {
      if (identical(_subscribedInFlight, request)) {
        _subscribedInFlight = null;
      }
    }).catchError((_) => const <PlayerSubscription>[]));
    _subscribedInFlight = request;
    return request;
  }

  Future<List<PlayerSubscription>> _fetchSubscribedPlayers() async {
    final sw = Stopwatch()..start();
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.playerSubscriptionsUrl),
        headers: _headers(token),
      ),
    );
    sw.stop();
    debugPrint('[Subscription] 구독선수 ← ${response.statusCode} '
        '(${sw.elapsedMilliseconds}ms)');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('구독 선수 조회 실패 (${response.statusCode})');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => PlayerSubscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 구독 가능한 선수를 검색한다 (페이지네이션).
  Future<PlayerPage> searchAvailablePlayers({
    String? query,
    int? teamId,
    int page = 0,
    int size = 20,
  }) async {
    final url = ApiConfig.availablePlayersUrl(
      query: query,
      teamId: teamId,
      page: page,
      size: size,
    );
    final sw = Stopwatch()..start();
    final response = await _auth.authorizedRequest(
      (token) => http.get(Uri.parse(url), headers: _headers(token)),
    );
    sw.stop();
    debugPrint('[Subscription] 가능선수 ← ${response.statusCode} '
        '(${sw.elapsedMilliseconds}ms, ${response.body.length} bytes)');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('구독 가능 선수 조회 실패 (${response.statusCode})');
    }
    return PlayerPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 선수를 구독한다.
  Future<PlayerSubscription> subscribePlayer(int playerId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.playerSubscriptionsUrl),
        headers: _headers(token),
        body: jsonEncode({'playerId': playerId}),
      ),
    );
    debugPrint('[Subscription] 선수구독 → $playerId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postSubscribe',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.playerSubscriptionsUrl, 'statusCode': response.statusCode, 'playerId': playerId},
      );
      throw Exception('선수 구독 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'postSubscribe', extra: {'playerId': playerId});
    _invalidateSubscribedPlayersCache();
    return PlayerSubscription.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 선수 구독을 해제한다.
  Future<void> unsubscribePlayer(int playerId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.playerSubscriptionUrl(playerId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Subscription] 선수해제 → $playerId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'deleteSubscribe',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.playerSubscriptionUrl(playerId), 'statusCode': response.statusCode, 'playerId': playerId},
      );
      throw Exception('선수 구독 해제 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'deleteSubscribe', extra: {'playerId': playerId});
    _invalidateSubscribedPlayersCache();
  }

  /// 선수별 솔랭 시작/종료 알림을 변경한다.
  ///
  /// 성공 시 204 No Content(빈 바디)로 응답해 파싱하지 않는다.
  Future<void> updatePlayerAlarm(
    int playerId, {
    required bool startEnabled,
    required bool endEnabled,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.playerSubscriptionUrl(playerId)),
        headers: _headers(token),
        body: jsonEncode({'startEnabled': startEnabled, 'endEnabled': endEnabled}),
      ),
    );
    debugPrint('[Subscription] 선수알림설정 → $playerId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postSubscribe',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.playerSubscriptionUrl(playerId), 'statusCode': response.statusCode, 'playerId': playerId},
      );
      throw Exception('선수 알림 설정 변경 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'postSubscribe', extra: {'playerId': playerId, 'action': 'updateAlarm'});
    _invalidateSubscribedPlayersCache();
  }

  // ── 팀 알림 구독 ──────────────────────────────────────────────────

  /// 내 팀 알림 구독 목록을 조회한다.
  Future<List<TeamNotificationSubscription>> fetchTeamNotifications() async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.teamNotificationsUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[Subscription] 팀알림 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('팀 알림 구독 조회 실패 (${response.statusCode})');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) =>
            TeamNotificationSubscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 구독 가능한 LCK 팀 목록을 조회한다.
  Future<List<TeamNotificationSubscription>> fetchAvailableTeams() async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.availableTeamsUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[Subscription] 가능팀 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('구독 가능 팀 조회 실패 (${response.statusCode})');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) =>
            TeamNotificationSubscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 팀 알림을 구독한다.
  Future<TeamNotificationSubscription> subscribeTeam(int teamId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.teamNotificationsUrl),
        headers: _headers(token),
        body: jsonEncode({'teamId': teamId}),
      ),
    );
    debugPrint('[Subscription] 팀구독 → $teamId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postSubscribe',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.teamNotificationsUrl, 'statusCode': response.statusCode, 'teamId': teamId},
      );
      throw Exception('팀 알림 구독 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'postSubscribe', extra: {'teamId': teamId});
    return TeamNotificationSubscription.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 팀별 알림 설정(세트 시작/종료·라이브·라이브 이벤트 세부 항목)을 변경한다.
  ///
  /// 성공 시 204 No Content(빈 바디)로 응답해 파싱하지 않는다.
  Future<void> updateTeamNotification(
    int teamId, {
    required bool setStartEnabled,
    required bool setEndEnabled,
    required bool liveEventEnabled,
    required bool killEnabled,
    required bool baronEnabled,
    required bool dragonEnabled,
    required bool towerEnabled,
    required bool inhibitorEnabled,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.teamNotificationUrl(teamId)),
        headers: _headers(token),
        body: jsonEncode({
          'setStartEnabled': setStartEnabled,
          'setEndEnabled': setEndEnabled,
          'liveEventEnabled': liveEventEnabled,
          'killEnabled': killEnabled,
          'baronEnabled': baronEnabled,
          'dragonEnabled': dragonEnabled,
          'towerEnabled': towerEnabled,
          'inhibitorEnabled': inhibitorEnabled,
        }),
      ),
    );
    debugPrint('[Subscription] 팀알림설정 → $teamId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postSubscribe',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.teamNotificationUrl(teamId), 'statusCode': response.statusCode, 'teamId': teamId},
      );
      throw Exception('팀 알림 설정 변경 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'postSubscribe', extra: {'teamId': teamId, 'action': 'updateNotification'});
  }

  /// 팀 알림 구독을 삭제한다.
  Future<void> unsubscribeTeam(int teamId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.teamNotificationUrl(teamId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Subscription] 팀해제 → $teamId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'deleteSubscribe',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.teamNotificationUrl(teamId), 'statusCode': response.statusCode, 'teamId': teamId},
      );
      throw Exception('팀 알림 구독 해제 실패 (${response.statusCode})');
    }
    SentryLogger.info(module: 'API', eventName: 'deleteSubscribe', extra: {'teamId': teamId});
  }
}
