import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/error/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/core/util/sentry_logger.dart';
import 'package:warding/features/my_review/data/mappers/my_rating_mapper.dart';
import 'package:warding/features/my_review/data/models/my_rating_dto.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';
import 'package:warding/features/my_review/domain/repositories/my_review_repository.dart';

/// [MyReviewRepository] 의 원격 구현.
///
/// 예외를 [Failure] 로 바꾸는 유일한 지점이다. 위 계층(ViewModel)은
/// `try/catch` 를 쓰지 않는다 — 그래서 실패 처리를 빠뜨리면 컴파일이
/// 통과하지 않는다.
///
/// DataSource 를 따로 두지 않는다. 이 repository 만 쓰는 호출이고 재사용할 데가
/// 없어서, 분리하면 파일 하나와 호출 한 단계만 늘어난다 — 교체 가능성도 Mock
/// 필요도 없는 계층은 추상화하지 않는다.
class MyReviewRepositoryImpl implements MyReviewRepository {
  MyReviewRepositoryImpl({AuthService? auth})
      : _auth = auth ?? AuthService.instance;

  final AuthService _auth;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  @override
  Future<Either<Failure, MyReviewPage>> fetchMyRatings({
    int page = 0,
    int size = 20,
  }) async {
    final url = ApiConfig.myRatingsUrl(page: page, size: size);
    try {
      final response = await _auth.authorizedRequest(
        (token) => http.get(Uri.parse(url), headers: _headers(token)),
      );
      debugPrint('[MyReview] 내평가목록 ← ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiStatusException(response.statusCode, endpoint: url);
      }
      final dto = MyRatingListDto.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      return Right(MyRatingMapper.toDomain(dto));
    } catch (e) {
      return Left(_toFailure(e, 'fetchMyRatings'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteMyRating({
    required String gameId,
    required int participantId,
  }) async {
    final url = ApiConfig.myRatingUrl(gameId, participantId);
    try {
      final response = await _auth.authorizedRequest(
        (token) => http.delete(Uri.parse(url), headers: _headers(token)),
      );
      debugPrint('[MyReview] 내평가 DELETE ← ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        SentryLogger.warning(
          module: 'API',
          eventName: 'deleteRating',
          reason: 'status_${response.statusCode}',
          extra: {
            'endpoint': url,
            'statusCode': response.statusCode,
            'gameId': gameId,
            'participantId': participantId,
          },
        );
        throw ApiStatusException(response.statusCode, endpoint: url);
      }
      SentryLogger.info(
        module: 'API',
        eventName: 'deleteRating',
        extra: {'gameId': gameId, 'participantId': participantId},
      );
      return const Right(unit);
    } catch (e) {
      return Left(_toFailure(e, 'deleteMyRating'));
    }
  }

  /// 예외 → [Failure]. 401 을 따로 가르는 이유는 화면이 "다시 로그인" 을
  /// 안내해야 하는 경우와 "잠시 후 다시" 를 안내하는 경우가 다르기 때문이다.
  Failure _toFailure(Object e, String op) {
    debugPrint('[MyReviewRepo] $op failed: $e');
    return switch (e) {
      ApiStatusException(statusCode: 401) ||
      ApiStatusException(statusCode: 403) =>
        UnauthorizedFailure(cause: e),
      ApiStatusException(:final statusCode) =>
        ServerFailure(statusCode: statusCode, cause: e),
      SocketException() || TimeoutException() => NetworkFailure(cause: e),
      FormatException() || TypeError() => ParseFailure(cause: e),
      _ => ServerFailure(cause: e),
    };
  }
}
