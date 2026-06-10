import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../model/game_rating.dart';
import '../auth/auth_service.dart';

/// 라이브 경기 선수 평점 API (`/api/mobile/live/games/...`).
///
/// 인증이 필요하다. [AuthService.authorizedRequest] 로 감싸 토큰 만료 시
/// 자동 갱신·재시도한다.
class RatingRepository {
  RatingRepository._();
  static final RatingRepository instance = RatingRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 세트(게임) 전체 선수 평점 목록을 조회한다.
  Future<GameRatings> fetchGameRatings(
    String gameId, {
    String teamSide = 'ALL',
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.gameRatingsUrl(gameId, teamSide: teamSide)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Rating] 세트평점 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('세트 평점 조회 실패 (${response.statusCode})');
    }
    return GameRatings.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 선수 평점 상세와 리뷰 목록을 조회한다 (페이지네이션).
  Future<PlayerRatingDetail> fetchPlayerRating(
    String gameId,
    int participantId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.playerRatingUrl(
          gameId,
          participantId,
          page: page,
          size: size,
        )),
        headers: _headers(token),
      ),
    );
    debugPrint('[Rating] 선수상세 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('선수 평점 상세 조회 실패 (${response.statusCode})');
    }
    return PlayerRatingDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 내 평가를 작성하거나 수정한다.
  Future<MyRating> putMyRating(
    String gameId,
    int participantId, {
    required int rating,
    String? comment,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.myRatingUrl(gameId, participantId)),
        headers: _headers(token),
        body: jsonEncode({'rating': rating, 'comment': comment}),
      ),
    );
    debugPrint('[Rating] 내평가 PUT ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('내 평가 저장 실패 (${response.statusCode})');
    }
    return MyRating.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// 내 평가를 삭제한다.
  Future<void> deleteMyRating(String gameId, int participantId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.myRatingUrl(gameId, participantId)),
        headers: _headers(token),
      ),
    );
    debugPrint('[Rating] 내평가 DELETE ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('내 평가 삭제 실패 (${response.statusCode})');
    }
  }
}
