import 'package:fpdart/fpdart.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/features/match_detail/domain/match_subscription_status.dart';

/// 경기 구독(예약 알림). 인증이 필요하다.
abstract interface class MatchSubscriptionRepository {
  /// 구독 중인 경기 ID 목록. [forceRefresh] 가 아니면 캐시를 재사용한다.
  Future<Either<Failure, Set<String>>> subscribedMatchIds({
    bool forceRefresh,
  });

  /// 경기를 구독(예약)한다. 이미 구독 중이면 멱등하게 통과한다.
  ///
  /// 알림 종류별 토글(세트 시작/종료·라이브 이벤트 + 라이브 세부 5종)을 함께
  /// 보낸다. 세부 5종은 `liveEventEnabled` 가 false 면 서버가 쓰지 않지만,
  /// 사용자가 고른 조합을 보존하려고 값은 그대로 보낸다.
  Future<Either<Failure, Unit>> subscribeMatch(
    String matchId, {
    bool setStartEnabled,
    bool setEndEnabled,
    bool liveEventEnabled,
    bool killEnabled,
    bool baronEnabled,
    bool dragonEnabled,
    bool towerEnabled,
    bool inhibitorEnabled,
  });

  /// 구독 상태와 알림 토글 조합.
  Future<Either<Failure, MatchSubscriptionStatus>> matchSubscriptionStatus(
    String matchId,
  );

  /// 알림 토글만 갱신한다. null 인 항목은 보내지 않아 서버 값이 유지된다.
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
  });

  /// 구독을 해제한다.
  Future<Either<Failure, Unit>> unsubscribeMatch(String matchId);
}
