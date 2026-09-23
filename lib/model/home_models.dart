// 홈 화면 전용 데이터 모델. ViewModel과 데이터 소스가 함께 참조한다.

/// 지금 솔로 랭크 중인 선수 카드 한 장.
class HomeLiveSoloPlayer {
  const HomeLiveSoloPlayer({
    required this.name,
    required this.teamCode,
    required this.champion,
    required this.elapsedSeconds,
    this.playerImageUrl,
  });

  final String name;
  final String teamCode;
  final String champion;
  final int elapsedSeconds;

  /// 선수 사진 URL(상대경로면 호스트 부착). 없으면 빈 자리 유지.
  final String? playerImageUrl;
}

/// 오늘 솔로 랭크를 끝낸 선수 한 명(최신 1건).
class HomeFinishedSoloPlayer {
  const HomeFinishedSoloPlayer({
    required this.name,
    required this.teamCode,
    required this.won,
    required this.minutesAgo,
    this.durationMinutes,
  });

  final String name;
  final String teamCode;
  final bool won;

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
    this.hasThumbnail = true,
  });

  final String title;
  final String office;
  final int minutesAgo;
  final bool hasThumbnail;
}

/// 콘텐츠 · 쇼츠 탭 한 건.
class HomeShortsVideo {
  const HomeShortsVideo({
    required this.title,
    required this.teamCode,
    required this.views,
    this.matchedPlayer,
    this.url = '',
    this.thumbnailUrl = '',
  });

  final String title;
  final String teamCode;
  final int views;

  /// 탭하면 여는 유튜브 주소. 비어 있으면 누를 수 없다.
  final String url;

  /// 썸네일 이미지 주소. 비어 있으면 빈 자리를 그린다.
  final String thumbnailUrl;

  /// 구독 선수와 제목이 매칭됐으면 그 선수 이름(보라 배지). 없으면 null.
  final String? matchedPlayer;
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
  });

  final String playerName;
  final String champion;
  final int stars;
  final String comment;
  final String nickname;
  final String teamCode;
  final int minutesAgo;
}
