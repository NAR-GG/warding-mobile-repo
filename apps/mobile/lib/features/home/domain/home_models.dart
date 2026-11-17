// 홈 화면 전용 데이터 모델. ViewModel과 데이터 소스가 함께 참조한다.

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

