import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:warding/core/util/api_client.dart' as http;

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/features/match_detail/domain/repositories/match_subscription_repository.dart';
import 'package:warding/features/match_detail/domain/match_subscription_status.dart';
import 'package:warding/core/util/sentry_logger.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';

/// 경기 예약(알림) 구독 API (`/api/mobile/me/match-subscriptions`).
///
/// 인증이 필요하다. 목록 조회 결과는 세션 동안 메모리에 캐시해 카드마다
/// 중복 조회하지 않고, 구독/해제 시 캐시를 낙관적으로 갱신한다.
class MatchSubscriptionRepositoryImpl
    implements MatchSubscriptionRepository {

  final AuthService _auth = AuthService.instance;

  Set<String>? _cache;
  Future<Either<Failure, Set<String>>>? _inFlight;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 구독 중인 경기 ID 목록을 조회한다. [forceRefresh] 가 아니면 캐시를 재사용한다.
  @override
  Future<Either<Failure, Set<String>>> subscribedMatchIds({
    bool forceRefresh = false,
  }) {
    final cached = _cache;
    if (!forceRefresh && cached != null) return Future.value(Right(cached));
    return _inFlight ??= _fetchAndCache();
  }

  /// **성공만 캐시한다.** 실패한 Either 를 캐시하면 다음 조회가 막힌다.
  Future<Either<Failure, Set<String>>> _fetchAndCache() async {
    try {
      final ids = await _fetchSubscribedMatchIds();
      _cache = ids;
      return Right(ids);
    } catch (e) {
      return Left(toFailure(e, op: 'subscribedMatchIds'));
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
      throw ApiStatusException(response.statusCode);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => e.toString()).toSet();
  }

  /// 경기를 구독(예약)한다. 이미 구독 중이면 멱등하게 통과한다.
  /// 알림 종류별 토글(세트 시작/종료·라이브 이벤트 + 라이브 세부 5종)을 함께 보낸다.
  ///
  /// 세부 5종은 `liveEventEnabled` 가 false 면 서버가 쓰지 않지만, 사용자가 고른
  /// 조합을 보존하려고 값은 그대로 보낸다.
  @override
  Future<Either<Failure, Unit>> subscribeMatch(
    String matchId, {
    bool setStartEnabled = true,
    bool setEndEnabled = true,
    bool liveEventEnabled = true,
    bool killEnabled = true,
    bool baronEnabled = true,
    bool dragonEnabled = true,
    bool towerEnabled = true,
    bool inhibitorEnabled = true,
  }) async {
    try {
      await _subscribeMatch(
        matchId,
        setStartEnabled: setStartEnabled,
        setEndEnabled: setEndEnabled,
        liveEventEnabled: liveEventEnabled,
        killEnabled: killEnabled,
        baronEnabled: baronEnabled,
        dragonEnabled: dragonEnabled,
        towerEnabled: towerEnabled,
        inhibitorEnabled: inhibitorEnabled,
      );
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'subscribeMatch'));
    }
  }

  Future<void> _subscribeMatch(
    String matchId, {
    bool setStartEnabled = true,
    bool setEndEnabled = true,
    bool liveEventEnabled = true,
    bool killEnabled = true,
    bool baronEnabled = true,
    bool dragonEnabled = true,
    bool towerEnabled = true,
    bool inhibitorEnabled = true,
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
          'killEnabled': killEnabled,
          'baronEnabled': baronEnabled,
          'dragonEnabled': dragonEnabled,
          'towerEnabled': towerEnabled,
          'inhibitorEnabled': inhibitorEnabled,
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
      throw ApiStatusException(response.statusCode);
    }
    SentryLogger.info(module: 'API', eventName: 'postMatchAlarm', extra: {'matchId': matchId});
    _cache = {...?_cache, matchId};
  }

  /// 그 경기의 알림 토글 상태를 조회한다.
  /// 구독 중이 아니면 서버가 `subscribed=false` 와 기본값을 돌려준다.
  @override
  Future<Either<Failure, MatchSubscriptionStatus>> matchSubscriptionStatus(
    String matchId,
  ) async {
    try {
      return Right(await _matchSubscriptionStatus(matchId));
    } catch (e) {
      return Left(toFailure(e, op: 'matchSubscriptionStatus'));
    }
  }

  Future<MatchSubscriptionStatus> _matchSubscriptionStatus(
      String matchId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.matchSubscriptionUrl(matchId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[MatchSubscription] 상태 → $matchId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(response.statusCode);
    }
    return MatchSubscriptionStatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 구독은 유지한 채 알림 종류만 켜고 끈다.
  /// 보내지 않은(null) 필드는 서버가 기존 값을 유지한다.
  @override
  Future<Either<Failure, Unit>> updateMatchAlarms(
    String matchId, {
    bool? setStartEnabled,
    bool? setEndEnabled,
    bool? liveEventEnabled,
    bool? killEnabled,
    bool? baronEnabled,
    bool? dragonEnabled,
    bool? towerEnabled,
    bool? inhibitorEnabled,
  }) async {
    try {
      await _updateMatchAlarms(
        matchId,
        setStartEnabled: setStartEnabled,
        setEndEnabled: setEndEnabled,
        liveEventEnabled: liveEventEnabled,
        killEnabled: killEnabled,
        baronEnabled: baronEnabled,
        dragonEnabled: dragonEnabled,
        towerEnabled: towerEnabled,
        inhibitorEnabled: inhibitorEnabled,
      );
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'updateMatchAlarms'));
    }
  }

  Future<void> _updateMatchAlarms(
    String matchId, {
    bool? setStartEnabled,
    bool? setEndEnabled,
    bool? liveEventEnabled,
    bool? killEnabled,
    bool? baronEnabled,
    bool? dragonEnabled,
    bool? towerEnabled,
    bool? inhibitorEnabled,
  }) async {
    final body = <String, bool>{
      'setStartEnabled': ?setStartEnabled,
      'setEndEnabled': ?setEndEnabled,
      'liveEventEnabled': ?liveEventEnabled,
      'killEnabled': ?killEnabled,
      'baronEnabled': ?baronEnabled,
      'dragonEnabled': ?dragonEnabled,
      'towerEnabled': ?towerEnabled,
      'inhibitorEnabled': ?inhibitorEnabled,
    };
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.matchSubscriptionUrl(matchId)),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
    debugPrint('[MatchSubscription] 토글 → $matchId ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'putMatchAlarm',
        reason: 'status_${response.statusCode}',
        extra: {
          'endpoint': ApiConfig.matchSubscriptionUrl(matchId),
          'statusCode': response.statusCode,
          'matchId': matchId,
        },
      );
      throw ApiStatusException(response.statusCode);
    }
    SentryLogger.info(
      module: 'API',
      eventName: 'putMatchAlarm',
      extra: {'matchId': matchId},
    );
  }

  /// 경기 구독을 해제한다.
  @override
  Future<Either<Failure, Unit>> unsubscribeMatch(String matchId) async {
    try {
      await _unsubscribeMatch(matchId);
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'unsubscribeMatch'));
    }
  }

  Future<void> _unsubscribeMatch(String matchId) async {
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
      throw ApiStatusException(response.statusCode);
    }
    SentryLogger.info(module: 'API', eventName: 'deleteMatchAlarm', extra: {'matchId': matchId});
    final cached = _cache;
    if (cached != null) _cache = {...cached}..remove(matchId);
  }
}
