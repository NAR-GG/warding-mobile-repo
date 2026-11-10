/// 내가 작성한 평가 한 건. (도메인)
///
/// JSON 을 모른다 — 서버 응답 모양은 `data/models/my_rating_dto.dart` 가 알고,
/// 변환은 `data/mappers/my_rating_mapper.dart` 가 한다. 그래서 서버 필드명이
/// 바뀌어도 이 파일과 이것을 쓰는 ViewModel·화면은 건드리지 않는다.
class MyReviewItem {
  const MyReviewItem({
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

  final RatedMatch? match;
}

/// 평가 대상 세트가 속한 매치 정보. 매핑이 없으면 null.
class RatedMatch {
  const RatedMatch({
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
}

/// 내 평가 목록 한 페이지.
class MyReviewPage {
  const MyReviewPage({
    required this.ratings,
    required this.page,
    required this.totalElements,
    required this.totalPages,
  });

  final List<MyReviewItem> ratings;
  final int page;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;
}
