import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:warding/core/config/api_config.dart';
import 'package:warding/core/infrastructure/api_status_exception.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/core/util/api_client.dart' as http;
import 'package:warding/core/util/sentry_logger.dart';
import 'package:warding/features/my_review/data/models/my_rating_dto.dart';

/// `me/ratings` 원격 호출.
///
/// 상태를 갖지 않고 데이터만 실어 온다. 2xx 가 아니면 예외를 던지고, 그것을
/// [Failure] 로 바꾸는 일은 repository 구현이 한다 — 이 계층은 HTTP 만 안다.
class MyReviewRemoteDataSource {
  MyReviewRemoteDataSource({AuthService? auth})
      : _auth = auth ?? AuthService.instance;

  final AuthService _auth;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 내가 작성한 평가 목록 한 페이지 (인증 필요).
  Future<MyRatingListDto> fetchMyRatings({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.myRatingsUrl(page: page, size: size)),
        headers: _headers(token),
      ),
    );
    debugPrint('[MyReview] 내평가목록 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiStatusException(
        response.statusCode,
        endpoint: ApiConfig.myRatingsUrl(page: page, size: size),
      );
    }
    return MyRatingListDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 평가 한 건 삭제.
  Future<void> deleteMyRating({
    required String gameId,
    required int participantId,
  }) async {
    final url = ApiConfig.myRatingUrl(gameId, participantId);
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
  }
}
