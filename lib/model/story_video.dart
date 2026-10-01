/// 유튜브 쇼츠 한 건. 서버 `VideoListResponse`의 일부 필드만 쓴다.
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

  factory StoryVideo.fromJson(Map<String, dynamic> json) {
    return StoryVideo(
      videoId: (json['videoId'] as num?)?.toInt() ?? 0,
      youtubeVideoId: json['youtubeVideoId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      videoUrl: json['videoUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      channelName: json['channelName'] as String? ?? '',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      teamCode: json['teamCode'] as String? ?? '',
      channelProfileUrl: json['channelProfileUrl'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }
}
