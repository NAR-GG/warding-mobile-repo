// 평점 한줄평 요약 모델. 홈 평점 섹션이 쓴다.

/// 커뮤니티 · 평점 한줄평 한 건.
class ReviewItem {
  const ReviewItem({
    required this.playerName,
    required this.champion,
    required this.stars,
    required this.comment,
    required this.nickname,
    required this.teamCode,
    required this.minutesAgo,
    this.gameId,
    this.participantId,
    this.playerId,
    this.teamSide,
    this.ratingId,
  });

  final String playerName;
  final String champion;
  final int stars;
  final String comment;
  final String nickname;
  final String teamCode;
  final int minutesAgo;

  /// 선수 평점 상세([PlayerRatingScreen]) 진입에 필요한 식별자. 셋 다 있어야
  /// 탭해서 그 선수의 평점 상세(한줄평 목록)로 이동할 수 있다.
  final String? gameId;
  final int? participantId;
  final int? playerId;

  /// 평가 대상 선수의 진영("BLUE"/"RED"). 팀 배지 색 판별에 쓴다.
  final String? teamSide;

  /// 이 한줄평의 평가 ID. 평점 상세 화면에서 이 한줄평으로 스크롤·강조하는
  /// 데 쓴다([PlayerRatingScreen.highlightRatingId]).
  final int? ratingId;
}
