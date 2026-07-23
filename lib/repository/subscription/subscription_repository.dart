import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  /// 내 구독 선수 목록을 조회한다.
  Future<List<PlayerSubscription>> fetchSubscribedPlayers() async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.playerSubscriptionsUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[Subscription] 구독선수 ← ${response.statusCode}');
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

  /// 팀별 알림 설정(세트 시작/종료·라이브)을 변경한다.
  Future<TeamNotificationSubscription> updateTeamNotification(
    int teamId, {
    required bool setStartEnabled,
    required bool setEndEnabled,
    required bool liveEventEnabled,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.teamNotificationUrl(teamId)),
        headers: _headers(token),
        body: jsonEncode({
          'setStartEnabled': setStartEnabled,
          'setEndEnabled': setEndEnabled,
          'liveEventEnabled': liveEventEnabled,
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
    return TeamNotificationSubscription.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
