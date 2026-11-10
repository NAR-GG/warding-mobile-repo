import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/features/my_review/data/datasources/my_review_remote_data_source.dart';
import 'package:warding/features/my_review/data/mappers/my_rating_mapper.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';
import 'package:warding/features/my_review/domain/repositories/my_review_repository.dart';

/// [MyReviewRepository] 의 원격 구현.
///
/// 예외를 [Failure] 로 바꾸는 유일한 지점이다. 위 계층(UseCase·ViewModel)은
/// `try/catch` 를 쓰지 않는다 — 그래서 실패 처리를 빠뜨리면 컴파일이
/// 통과하지 않는다.
class MyReviewRepositoryImpl implements MyReviewRepository {
  MyReviewRepositoryImpl({MyReviewRemoteDataSource? remote})
      : _remote = remote ?? MyReviewRemoteDataSource();

  final MyReviewRemoteDataSource _remote;

  @override
  Future<Either<Failure, MyReviewPage>> fetchMyRatings({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final dto = await _remote.fetchMyRatings(page: page, size: size);
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
    try {
      await _remote.deleteMyRating(
        gameId: gameId,
        participantId: participantId,
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
