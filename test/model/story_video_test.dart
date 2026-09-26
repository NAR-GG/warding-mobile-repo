import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/story_video.dart';

void main() {
  test('필드를 그대로 파싱한다', () {
    final v = StoryVideo.fromJson({
      'videoId': 1001,
      'youtubeVideoId': 'abc123',
      'title': '제우스 하이라이트',
      'videoUrl': 'https://youtube.com/watch?v=abc123',
      'thumbnailUrl': 'https://img/t.jpg',
      'channelName': 'LCK',
      'viewCount': 12345,
      'publishedAt': '2026-09-20T10:00:00',
    });
    expect(v.title, '제우스 하이라이트');
    expect(v.viewCount, 12345);
    expect(v.publishedAt, DateTime.parse('2026-09-20T10:00:00'));
  });

  test('필드 누락에도 죽지 않는다', () {
    final v = StoryVideo.fromJson(const {});
    expect(v.videoId, 0);
    expect(v.publishedAt, isNull);
  });
}
