// 마이페이지 '내 리뷰/평점' 서버 응답 DTO (`GET /api/mobile/me/ratings`).
//
// 서버 응답 모양만 안다. 도메인 타입(`domain/entities/my_rating.dart`) 으로의
// 변환은 `data/mappers/my_rating_mapper.dart` 가 한다 — 서버 필드명이 바뀌면
// 이 파일과 mapper 만 고치면 된다.

/// 내가 작성한 평가 전체 목록 응답.
class MyRatingListDto {
  const MyRatingListDto({
    required this.ratings,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<MyRatingItemDto> ratings;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;


  factory MyRatingListDto.fromJson(Map<String, dynamic> json) {
    return MyRatingListDto(
      ratings: (json['ratings'] as List<dynamic>? ?? const [])
          .map((e) => MyRatingItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}

/// 내가 작성한 평가 한 건.
class MyRatingItemDto {
  const MyRatingItemDto({
    required this.ratingId,
    required this.gameId,
    required this.participantId,
    required this.playerId,
    required this.playerName,
    required this.playerImageUrl,
    required this.teamSide,
    required this.role,
    required this.championName,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
    this.profileImageUrl,
    this.teamImageUrl,
    this.match,
  });

  final int ratingId;
  final String gameId;
  final int participantId;
  final int playerId;
  final String playerName;
  final String playerImageUrl;
  final String teamSide;
  final String role;
  final String championName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 작성자(나) 프로필 이미지 URL. 없으면 placeholder.
  final String? profileImageUrl;

  /// 작성자(나) 응원팀 로고 URL. 없으면 placeholder.
  final String? teamImageUrl;

  final MatchInfoDto? match;

  factory MyRatingItemDto.fromJson(Map<String, dynamic> json) {
    final m = json['match'];
    return MyRatingItemDto(
      ratingId: json['ratingId'] as int? ?? 0,
      gameId: json['gameId'] as String? ?? '',
      participantId: json['participantId'] as int? ?? 0,
      playerId: json['playerId'] as int? ?? 0,
      playerName: json['playerName'] as String? ?? '',
      playerImageUrl: json['playerImageUrl'] as String? ?? '',
      teamSide: json['teamSide'] as String? ?? '',
      role: json['role'] as String? ?? '',
      championName: json['championName'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      profileImageUrl: json['profileImageUrl'] as String?,
      teamImageUrl: json['teamImageUrl'] as String?,
      match: m == null ? null : MatchInfoDto.fromJson(m as Map<String, dynamic>),
    );
  }
}

/// 평가 대상 세트가 속한 매치 정보. 매핑이 없으면 null.
class MatchInfoDto {
  const MatchInfoDto({
    required this.matchId,
    required this.gameOrder,
    required this.leagueName,
    required this.matchTitle,
    required this.blueTeamCode,
    required this.redTeamCode,
    this.matchDate,
  });

  final String matchId;
  final int gameOrder;
  final String leagueName;
  final String matchTitle;
  final String blueTeamCode;
  final String redTeamCode;
  final DateTime? matchDate;

  factory MatchInfoDto.fromJson(Map<String, dynamic> json) {
    return MatchInfoDto(
      matchId: json['matchId'] as String? ?? '',
      gameOrder: json['gameOrder'] as int? ?? 0,
      leagueName: json['leagueName'] as String? ?? '',
      matchTitle: json['matchTitle'] as String? ?? '',
      blueTeamCode: json['blueTeamCode'] as String? ?? '',
      redTeamCode: json['redTeamCode'] as String? ?? '',
      matchDate: DateTime.tryParse(json['matchDate'] as String? ?? ''),
    );
  }
}
