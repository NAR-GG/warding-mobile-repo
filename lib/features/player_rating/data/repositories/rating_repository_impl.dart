import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/core/data/failure_mapper.dart';
import 'package:warding/core/error/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/features/player_rating/domain/repositories/rating_repository.dart';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/features/player_rating/domain/game_rating.dart';
import 'package:warding/core/util/sentry_logger.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';

/// 라이브 경기 선수 평점 API (`/api/mobile/live/games/...`).
///
/// 인증이 필요하다. [AuthService.authorizedRequest] 로 감싸 토큰 만료 시
/// 자동 갱신·재시도한다.
class RatingRepositoryImpl implements RatingRepository {

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 토큰이 있으면 인증 헤더를 실어 보내고(만료 시 자동 갱신), 없으면 무토큰 GET.
  /// 비회원도 조회할 수 있게 한다. (myRating/mine 은 토큰이 있을 때만 채워짐)
  Future<http.Response> _optionalAuthGet(String url) async {
    final token = await _auth.jwt;
    if (token == null || token.isEmpty) {
      return http.get(Uri.parse(url));
    }
    return _auth.authorizedRequest(
      (t) => http.get(Uri.parse(url), headers: _headers(t)),
    );
  }

  /// 세트(게임) 전체 선수 평점 목록을 조회한다.
  @override
  Future<Either<Failure, GameRatings>> fetchGameRatings(
    String gameId, {
    String teamSide = 'ALL',
  }) async {
    final url = ApiConfig.gameRatingsUrl(gameId, teamSide: teamSide);
    try {
      final response = await _optionalAuthGet(url);
      debugPrint('[Rating] 세트평점 ← ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiStatusException(response.statusCode, endpoint: url);
      }
      return Right(
        GameRatings.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
      );
    } catch (e) {
      return Left(toFailure(e, op: 'fetchGameRatings'));
    }
  }

  /// 선수 평점 상세와 리뷰 목록을 조회한다 (페이지네이션).
  @override
  Future<Either<Failure, PlayerRatingDetail>> fetchPlayerRating(
    String gameId,
    int participantId, {
    int page = 0,
    int size = 20,
  }) async {
    final url =
        ApiConfig.playerRatingUrl(gameId, participantId, page: page, size: size);
    try {
      final response = await _optionalAuthGet(url);
      debugPrint('[Rating] 선수상세 ← ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiStatusException(response.statusCode, endpoint: url);
      }
      return Right(PlayerRatingDetail.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      ));
    } catch (e) {
      return Left(toFailure(e, op: 'fetchPlayerRating'));
    }
  }

  /// 내 평가를 작성하거나 수정한다.
  @override
  Future<Either<Failure, MyRating>> putMyRating(
    String gameId,
    int participantId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.myRatingUrl(gameId, participantId)),
        headers: _headers(token),
        body: jsonEncode({'rating': rating, 'comment': comment}),
      ),
    );
    debugPrint('[Rating] 내평가 PUT ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'postRating',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.myRatingUrl(gameId, participantId), 'statusCode': response.statusCode, 'gameId': gameId, 'participantId': participantId},
      );
      throw ApiStatusException(
          response.statusCode,
          endpoint: ApiConfig.myRatingUrl(gameId, participantId),
        );
      }
      SentryLogger.info(module: 'API', eventName: 'postRating', extra: {'gameId': gameId, 'participantId': participantId});
      return Right(
        MyRating.fromJson(jsonDecode(response.body) as Map<String, dynamic>),
      );
    } catch (e) {
      return Left(toFailure(e, op: 'putMyRating'));
    }
  }

  /// 내 평가를 삭제한다.
  @override
  Future<Either<Failure, Unit>> deleteMyRating(
    String gameId,
    int participantId,
  ) async {
    try {
      final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.myRatingUrl(gameId, participantId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Rating] 내평가 DELETE ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'deleteRating',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.myRatingUrl(gameId, participantId), 'statusCode': response.statusCode, 'gameId': gameId, 'participantId': participantId},
      );
      throw ApiStatusException(
          response.statusCode,
          endpoint: ApiConfig.myRatingUrl(gameId, participantId),
        );
      }
      SentryLogger.info(module: 'API', eventName: 'deleteRating', extra: {'gameId': gameId, 'participantId': participantId});
      return const Right(unit);
    } catch (e) {
      return Left(toFailure(e, op: 'deleteMyRating'));
    }
  }
}
