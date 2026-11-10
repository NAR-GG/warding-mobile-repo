import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/domain/player_subscription.dart';
import 'package:warding/core/domain/team_notification_subscription.dart';

/// 선수·팀 구독과 알림 설정. 인증이 필요하다.
abstract interface class SubscriptionRepository {
  /// 내가 구독한 선수 목록.
  ///
  /// 같은 조회가 이미 떠 있으면 합류한다 — 홈·내 선수·선수 페이지가 거의
  /// 동시에 부른다.
  Future<Either<Failure, List<PlayerSubscription>>> fetchSubscribedPlayers();

  /// 구독 가능한 선수 검색 (페이지네이션).
  Future<Either<Failure, PlayerPage>> searchAvailablePlayers({
    String? query,
    int? teamId,
    int page,
    int size,
  });

  /// 선수 구독.
  Future<Either<Failure, PlayerSubscription>> subscribePlayer(int playerId);

  /// 선수 구독 해제.
  Future<Either<Failure, Unit>> unsubscribePlayer(int playerId);

  /// 선수 알림 토글. 서버가 204 로 응답해 바디가 없다.
  Future<Either<Failure, Unit>> updatePlayerAlarm(
    int playerId, {
    required bool startEnabled,
    required bool endEnabled,
  });

  /// 내 팀 알림 구독 목록.
  Future<Either<Failure, List<TeamNotificationSubscription>>>
      fetchTeamNotifications();

  /// 구독 가능한 팀 목록.
  Future<Either<Failure, List<TeamNotificationSubscription>>>
      fetchAvailableTeams();

  /// 팀 구독.
  Future<Either<Failure, TeamNotificationSubscription>> subscribeTeam(
    int teamId,
  );

  /// 팀 알림 토글. 서버가 204 로 응답해 바디가 없다.
  Future<Either<Failure, Unit>> updateTeamNotification(
    int teamId, {
    required bool setStartEnabled,
    required bool setEndEnabled,
    required bool liveEventEnabled,
    required bool killEnabled,
    required bool baronEnabled,
    required bool dragonEnabled,
    required bool towerEnabled,
    required bool inhibitorEnabled,
  });

  /// 팀 구독 해제.
  Future<Either<Failure, Unit>> unsubscribeTeam(int teamId);
}
