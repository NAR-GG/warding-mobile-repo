import 'package:fpdart/fpdart.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/features/player_rating/domain/game_rating.dart';

/// 라이브 경기 선수 평점 (`/api/mobile/live/games/...`).
///
/// 조회는 비회원도 가능하고(토큰이 있으면 내 평가가 함께 채워진다), 작성·삭제는
/// 인증이 필요하다.
abstract interface class RatingRepository {
  /// 세트(게임) 전체 선수 평점 목록.
  Future<Either<Failure, GameRatings>> fetchGameRatings(
    String gameId, {
    String teamSide,
  });

  /// 선수 평점 상세와 리뷰 목록 (페이지네이션).
  Future<Either<Failure, PlayerRatingDetail>> fetchPlayerRating(
    String gameId,
    int participantId, {
    int page,
    int size,
  });

  /// 내 평가를 작성하거나 수정한다.
  Future<Either<Failure, MyRating>> putMyRating(
    String gameId,
    int participantId, {
    required int rating,
    String? comment,
  });

  /// 내 평가를 지운다.
  Future<Either<Failure, Unit>> deleteMyRating(
    String gameId,
    int participantId,
  );
}
