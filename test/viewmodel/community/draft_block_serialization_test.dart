import 'package:flutter_test/flutter_test.dart';
import 'package:warding/viewmodel/community/post_write_viewmodel.dart';

/// 임시저장은 [DraftBlock] 을 JSON 으로 직렬화해 기기에 보관한다 — 서버로 나가는
/// [CommunityPostBlock] 과 달리 아직 업로드 전인 localPath 도 함께 보존해야 한다.
void main() {
  test('text 블록은 heading 포함해 라운드트립된다', () {
    const block = DraftBlock.text('본문', heading: true);
    final restored = DraftBlock.fromJson(block.toJson());
    expect(restored.type, 'text');
    expect(restored.text, '본문');
    expect(restored.heading, isTrue);
  });

  test('image 블록은 localPath 를 보존한다', () {
    const block = DraftBlock.image(localPath: '/tmp/a.jpg');
    final restored = DraftBlock.fromJson(block.toJson());
    expect(restored.type, 'image');
    expect(restored.localPath, '/tmp/a.jpg');
    expect(restored.url, isNull);
  });

  test('link 블록은 프리뷰 필드를 모두 보존한다', () {
    const block = DraftBlock.link(
      url: 'https://a.com',
      title: 't',
      description: 'd',
      imageUrl: 'https://a.com/i.png',
      siteName: 's',
    );
    final restored = DraftBlock.fromJson(block.toJson());
    expect(restored.type, 'link');
    expect(restored.url, 'https://a.com');
    expect(restored.title, 't');
    expect(restored.description, 'd');
    expect(restored.imageUrl, 'https://a.com/i.png');
    expect(restored.siteName, 's');
  });

  test('embed 블록은 provider 와 url 을 보존한다', () {
    const block = DraftBlock.embed(provider: 'youtube', url: 'https://youtu.be/x');
    final restored = DraftBlock.fromJson(block.toJson());
    expect(restored.type, 'embed');
    expect(restored.provider, 'youtube');
    expect(restored.url, 'https://youtu.be/x');
  });

  test('encodeList/decodeList 는 블록 순서를 보존한다', () {
    const blocks = [
      DraftBlock.text('첫줄'),
      DraftBlock.image(localPath: '/tmp/a.jpg'),
      DraftBlock.text('둘째줄'),
    ];

    final restored = DraftBlock.decodeList(DraftBlock.encodeList(blocks));

    expect(restored.map((b) => b.type).toList(), ['text', 'image', 'text']);
    expect(restored[0].text, '첫줄');
    expect(restored[2].text, '둘째줄');
  });

  test('decodeList 는 손상된 JSON 이면 빈 목록을 준다', () {
    expect(DraftBlock.decodeList('not json'), isEmpty);
  });
}
