// 선수 평점 관련 모델 (`/api/mobile/live/games/...`).

/// 세트(게임) 전체 선수 평점 목록. `GET /games/{gameId}/ratings` 응답.
class GameRatings {
  const GameRatings({
    required this.gameId,
    required this.rateable,
    required this.teams,
    required this.players,
  });

  final String gameId;

  /// 평점 작성 가능 여부 (세트 종료 후 true).
  final bool rateable;

  final List<TeamRatingSummary> teams;
  final List<RatingPlayer> players;

  factory GameRatings.fromJson(Map<String, dynamic> json) {
    return GameRatings(
      gameId: json['gameId'] as String? ?? '',
      rateable: json['rateable'] as bool? ?? false,
      teams: (json['teams'] as List<dynamic>? ?? const [])
          .map((e) => TeamRatingSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      players: (json['players'] as List<dynamic>? ?? const [])
          .map((e) => RatingPlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 팀별 평점 요약.
class TeamRatingSummary {
  const TeamRatingSummary({
    required this.teamSide,
    required this.teamName,
    required this.averageRating,
    required this.ratingCount,
  });

  final String teamSide;
  final String teamName;
  final double averageRating;
  final int ratingCount;

  factory TeamRatingSummary.fromJson(Map<String, dynamic> json) {
    return TeamRatingSummary(
      teamSide: json['teamSide'] as String? ?? '',
      teamName: json['teamName'] as String? ?? '',
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] as int? ?? 0,
    );
  }
}

/// 세트 목록의 선수 한 명(요약).
class RatingPlayer {
  const RatingPlayer({
    required this.participantId,
    required this.playerId,
    required this.playerName,
    required this.playerImageUrl,
    required this.teamSide,
    required this.role,
    required this.championName,
    required this.averageRating,
    required this.ratingCount,
    required this.myRating,
  });

  final int participantId;
  final int playerId;
  final String playerName;
  final String playerImageUrl;
  final String teamSide;
  final String role;
  final String championName;
  final double averageRating;
  final int ratingCount;

  /// 내가 준 평점 (0이면 미평가).
  final double myRating;

  factory RatingPlayer.fromJson(Map<String, dynamic> json) {
    return RatingPlayer(
      participantId: json['participantId'] as int? ?? 0,
      playerId: json['playerId'] as int? ?? 0,
      playerName: json['playerName'] as String? ?? '',
      playerImageUrl: json['playerImageUrl'] as String? ?? '',
      teamSide: json['teamSide'] as String? ?? '',
      role: json['role'] as String? ?? '',
      championName: json['championName'] as String? ?? '',
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      myRating: (json['myRating'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 선수 평점 상세 + 리뷰. `GET /participants/{participantId}/ratings` 응답.
class PlayerRatingDetail {
  const PlayerRatingDetail({
    required this.gameId,
    required this.rateable,
    required this.player,
    required this.averageRating,
    required this.ratingCount,
    required this.distribution,
    required this.myRating,
    required this.reviews,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final String gameId;
  final bool rateable;
  final RatingPlayerDetail player;
  final double averageRating;
  final int ratingCount;

  /// 5점부터 1점까지의 분포.
  final List<RatingDistribution> distribution;

  /// 내 평가. 없으면 null.
  final MyRating? myRating;

  final List<Review> reviews;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  factory PlayerRatingDetail.fromJson(Map<String, dynamic> json) {
    final my = json['myRating'];
    return PlayerRatingDetail(
      gameId: json['gameId'] as String? ?? '',
      rateable: json['rateable'] as bool? ?? false,
      player: RatingPlayerDetail.fromJson(
        json['player'] as Map<String, dynamic>? ?? const {},
      ),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      distribution: (json['distribution'] as List<dynamic>? ?? const [])
          .map((e) => RatingDistribution.fromJson(e as Map<String, dynamic>))
          .toList(),
      myRating: my == null ? null : MyRating.fromJson(my as Map<String, dynamic>),
      reviews: (json['reviews'] as List<dynamic>? ?? const [])
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}

/// 평점 상세의 선수 정보(KDA 포함).
class RatingPlayerDetail {
  const RatingPlayerDetail({
    required this.participantId,
    required this.playerId,
    required this.playerName,
    required this.playerImageUrl,
    required this.teamSide,
    required this.role,
    required this.championName,
    required this.kills,
    required this.deaths,
    required this.assists,
  });

  final int participantId;
  final int playerId;
  final String playerName;
  final String playerImageUrl;
  final String teamSide;
  final String role;
  final String championName;
  final int kills;
  final int deaths;
  final int assists;

  String get kda => '$kills/$deaths/$assists';

  factory RatingPlayerDetail.fromJson(Map<String, dynamic> json) {
    return RatingPlayerDetail(
      participantId: json['participantId'] as int? ?? 0,
      playerId: json['playerId'] as int? ?? 0,
      playerName: json['playerName'] as String? ?? '',
      playerImageUrl: json['playerImageUrl'] as String? ?? '',
      teamSide: json['teamSide'] as String? ?? '',
      role: json['role'] as String? ?? '',
      championName: json['championName'] as String? ?? '',
      kills: json['kills'] as int? ?? 0,
      deaths: json['deaths'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
    );
  }
}

/// 별점 분포 한 칸.
class RatingDistribution {
  const RatingDistribution({
    required this.rating,
    required this.count,
    required this.percentage,
  });

  final int rating;
  final int count;
  final double percentage;

  factory RatingDistribution.fromJson(Map<String, dynamic> json) {
    return RatingDistribution(
      rating: json['rating'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 내 평가. `PUT/DELETE my-rating` 및 상세 응답의 myRating.
class MyRating {
  const MyRating({
    required this.ratingId,
    required this.rating,
    this.comment,
  });

  final int ratingId;
  final double rating;
  final String? comment;

  factory MyRating.fromJson(Map<String, dynamic> json) {
    return MyRating(
      ratingId: json['ratingId'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
    );
  }
}

/// 다른 사용자의 리뷰 한 건.
class Review {
  const Review({
    required this.ratingId,
    required this.nickname,
    required this.rating,
    this.comment,
    required this.mine,
    this.createdAt,
    this.updatedAt,
  });

  final int ratingId;
  final String nickname;
  final double rating;
  final String? comment;

  /// 내가 쓴 리뷰인지.
  final bool mine;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      ratingId: json['ratingId'] as int? ?? 0,
      nickname: json['nickname'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
      mine: json['mine'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
