// 홈 화면 전용 데이터 모델. ViewModel과 데이터 소스가 함께 참조한다.

/// 콘텐츠 · 뉴스 탭 한 건.
class HomeNewsArticle {
  const HomeNewsArticle({
    required this.title,
    required this.office,
    required this.minutesAgo,
    this.thumbnailUrl,
    this.postUrl,
  });

  final String title;
  final String office;
  final int minutesAgo;

  /// 기사 썸네일 URL. 없으면 빈 자리를 그린다.
  final String? thumbnailUrl;

  /// 기사 원문 URL. 없으면 탭해도 이동하지 않는다.
  final String? postUrl;
}

/// 콘텐츠 · 쇼츠 탭 한 건.
class HomeShortsVideo {
  const HomeShortsVideo({
    required this.title,
    required this.teamCode,
    required this.views,
    this.url = '',
    this.thumbnailUrl = '',
    this.youtubeVideoId = '',
  });

  final String title;
  final String teamCode;
  final int views;

  /// 탭하면 여는 유튜브 주소. 비어 있으면 누를 수 없다.
  final String url;

  /// 썸네일 이미지 주소. 비어 있으면 빈 자리를 그린다.
  final String thumbnailUrl;

  /// 세로 썸네일(`oardefault.jpg`)을 만드는 데 쓰는 유튜브 영상 ID.
  final String youtubeVideoId;

  /// 서버가 주는 4:3 썸네일 대신 먼저 시도하는 9:16 세로 썸네일. 영상 ID 가
  /// 없으면 null. 일부 영상엔 없어(404) 카드가 [thumbnailUrl] 로 폴백한다.
  String? get verticalThumbnailUrl => youtubeVideoId.isEmpty
      ? null
      : 'https://i.ytimg.com/vi/$youtubeVideoId/oardefault.jpg';
}

/// 커뮤니티 · 평점 한줄평 한 건.
class HomeReviewItem {
  const HomeReviewItem({
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
