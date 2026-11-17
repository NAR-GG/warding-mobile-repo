/// 유튜브 쇼츠 한 건. (도메인)
///
/// JSON 을 모른다 — 서버 응답 모양은 `data/models/story_video_dto.dart` 가 안다.
class StoryVideo {
  const StoryVideo({
    required this.videoId,
    required this.youtubeVideoId,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.channelName,
    required this.viewCount,
    this.teamCode = '',
    this.channelProfileUrl = '',
    this.publishedAt,
  });

  final int videoId;
  final String youtubeVideoId;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String channelName;
  final int viewCount;

  /// 채널의 팀 코드. LCK 공식 채널이나 서버가 아직 안 주는 동안은 빈 문자열.
  final String teamCode;

  /// 채널 프로필 이미지. 없으면 빈 문자열.
  final String channelProfileUrl;
  final DateTime? publishedAt;
}

/// 쇼츠 목록 한 페이지. [isLast] 가 true 면 다음 페이지가 없다.
class ShortsPage {
  const ShortsPage({required this.items, required this.isLast});

  final List<StoryVideo> items;
  final bool isLast;
}
