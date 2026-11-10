import 'package:warding/features/my_review/data/models/my_rating_dto.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';

/// DTO → Entity 변환.
///
/// 추상화하지 않는다. 변환 함수는 플랫폼·라이브러리에 의존하지 않고 교체할
/// 이유도 없어서, 인터페이스를 두면 간접층만 늘어난다.
class MyRatingMapper {
  const MyRatingMapper._();

  static MyReviewPage toDomain(MyRatingListDto dto) {
    return MyReviewPage(
      ratings: dto.ratings.map(_itemToDomain).toList(),
      page: dto.page,
      totalElements: dto.totalElements,
      totalPages: dto.totalPages,
    );
  }

  static MyReviewItem _itemToDomain(MyRatingItemDto dto) {
    return MyReviewItem(
      ratingId: dto.ratingId,
      gameId: dto.gameId,
      participantId: dto.participantId,
      playerId: dto.playerId,
      playerName: dto.playerName,
      playerImageUrl: dto.playerImageUrl,
      teamSide: dto.teamSide,
      role: dto.role,
      championName: dto.championName,
      rating: dto.rating,
      comment: dto.comment,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      profileImageUrl: dto.profileImageUrl,
      teamImageUrl: dto.teamImageUrl,
      match: dto.match == null ? null : _matchToDomain(dto.match!),
    );
  }

  static RatedMatch _matchToDomain(MatchInfoDto dto) {
    return RatedMatch(
      matchId: dto.matchId,
      gameOrder: dto.gameOrder,
      leagueName: dto.leagueName,
      matchTitle: dto.matchTitle,
      blueTeamCode: dto.blueTeamCode,
      redTeamCode: dto.redTeamCode,
      matchDate: dto.matchDate,
    );
  }
}
