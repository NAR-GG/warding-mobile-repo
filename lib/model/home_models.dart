// 홈 화면 전용 데이터 모델. ViewModel과 데이터 소스가 함께 참조한다.

/// 지금 솔로 랭크 중인 선수 카드 한 장.
class HomeLiveSoloPlayer {
  const HomeLiveSoloPlayer({
    required this.name,
    required this.teamCode,
    required this.champion,
    required this.elapsedSeconds,
    this.playerImageUrl,
    this.startedAt,
  });

  final String name;
  final String teamCode;
  final String champion;

  /// 조회 시점 기준 경과 시간(초). [startedAt] 이 있으면 화면은 그 시각으로
  /// 초 단위 카운트업하고, 이 값은 게임 길이 안내 등 조회 시점 스냅샷에만 쓴다.
  final int elapsedSeconds;

  /// 선수 사진 URL(상대경로면 호스트 부착). 없으면 빈 자리 유지.
  final String? playerImageUrl;

  /// 게임 시작 시각. 있으면 기기 시계로 [elapsedSeconds] 를 매초 다시 계산해
  /// 카운트업한다(spec 미룬 것 — "기기 시계 카운트업"). 없으면 [elapsedSeconds]
  /// 를 고정값으로 보여준다.
  final DateTime? startedAt;
}

/// 오늘 솔로 랭크를 끝낸 선수 한 명(최신 1건).
class HomeFinishedSoloPlayer {
  const HomeFinishedSoloPlayer({
    required this.name,
    required this.teamCode,
    required this.won,
    required this.minutesAgo,
    this.durationMinutes,
    this.playerImageUrl,
  });

  final String name;
  final String teamCode;
  final bool won;

  /// 선수 사진 URL(상대경로면 호스트 부착). 없으면 이름 이니셜로 대신한다.
  final String? playerImageUrl;

  /// 끝난 지 몇 분 됐는지 — "12분 전 종료".
  final int minutesAgo;

  /// 경기 길이(분) — "32분". 소스가 주지 않으면 null 이고 그리지 않는다.
  final int? durationMinutes;
}

/// 순위표 리그 칩 하나. [live]가 false면 아직 데이터가 없는 리그(탭 불가).
class HomeLeagueChip {
  const HomeLeagueChip({
    required this.code,
    required this.label,
    required this.live,
  });

  final String code;
  final String label;
  final bool live;
}

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
