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
    this.publishedAt,
  });

  final int videoId;
  final String youtubeVideoId;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String channelName;
  final int viewCount;
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
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }
}
