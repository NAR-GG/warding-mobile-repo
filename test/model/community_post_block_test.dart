import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_post_block.dart';

void main() {
  group('CommunityPostBlock', () {
    test('블록 JSON 왕복 — parse 후 encode 해도 계약 필드가 보존된다', () {
      const body = '[{"type":"text","text":"안녕","style":"heading"},'
          '{"type":"image","url":"https://res.cloudinary.com/x/a.jpg"},'
          '{"type":"link","url":"https://a.com","title":"t","siteName":"s"},'
          '{"type":"embed","provider":"youtube","url":"https://youtu.be/abc"}]';
      final blocks = CommunityPostBlock.parseList(body);
      expect(blocks, hasLength(4));
      expect(blocks[0].isHeading, isTrue);
      expect(blocks[3].provider, 'youtube');

      final encoded = CommunityPostBlock.encodeList(blocks);
      final again = CommunityPostBlock.parseList(encoded);
      expect(again[1].url, 'https://res.cloudinary.com/x/a.jpg');
      expect(again[2].title, 't');
    });

    test('깨진 JSON·배열 아님은 빈 목록 — 렌더러가 평문 폴백을 탄다', () {
      expect(CommunityPostBlock.parseList('평문 본문'), isEmpty);
      expect(CommunityPostBlock.parseList('{"type":"text"}'), isEmpty);
    });

    test('임베드 제공자 판별 — 위장 도메인은 안 걸린다', () {
      expect(CommunityPostBlock.embedProviderOf('https://www.youtube.com/watch?v=a'),
          'youtube');
      expect(CommunityPostBlock.embedProviderOf('https://youtu.be/a'), 'youtube');
      expect(CommunityPostBlock.embedProviderOf('https://chzzk.naver.com/live/x'),
          'chzzk');
      expect(CommunityPostBlock.embedProviderOf('https://play.sooplive.co.kr/x'),
          'soop');
      expect(CommunityPostBlock.embedProviderOf('https://x.com/user/status/1'), 'x');
      // youtube.com 으로 끝나는 위장 호스트는 suffix 매칭('.youtube.com')에 안 걸린다.
      expect(CommunityPostBlock.embedProviderOf('https://evilyoutube.com/x'), isNull);
      expect(CommunityPostBlock.embedProviderOf('https://youtube.com.evil.com/x'),
          isNull);
      expect(CommunityPostBlock.embedProviderOf('https://news.example.com/a'), isNull);
    });

    test('유튜브 영상 id — watch/shorts/youtu.be 전부에서 뽑는다', () {
      expect(CommunityPostBlock.youtubeVideoId('https://www.youtube.com/watch?v=dQw4'),
          'dQw4');
      expect(CommunityPostBlock.youtubeVideoId('https://youtu.be/dQw4'), 'dQw4');
      expect(CommunityPostBlock.youtubeVideoId('https://youtube.com/shorts/abc123'),
          'abc123');
      expect(CommunityPostBlock.youtubeVideoId('https://youtube.com/'), isNull);
    });
  });
}
