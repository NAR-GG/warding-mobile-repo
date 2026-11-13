import 'package:warding/features/shorts/data/models/story_video_dto.dart';
import 'package:warding/features/shorts/domain/entities/story_video.dart';

/// DTO → Entity 변환. 추상화하지 않는다.
class ShortsMapper {
  const ShortsMapper._();

  static StoryVideo toDomain(StoryVideoDto dto) => StoryVideo(
        videoId: dto.videoId,
        youtubeVideoId: dto.youtubeVideoId,
        title: dto.title,
        videoUrl: dto.videoUrl,
        thumbnailUrl: dto.thumbnailUrl,
        channelName: dto.channelName,
        viewCount: dto.viewCount,
        teamCode: dto.teamCode,
        channelProfileUrl: dto.channelProfileUrl,
        publishedAt: dto.publishedAt,
      );

  static ShortsPage pageToDomain(
    List<StoryVideoDto> dtos, {
    required bool isLast,
  }) =>
      ShortsPage(
        items: dtos.map(toDomain).toList(),
        isLast: isLast,
      );
}
