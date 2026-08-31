import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_draft.dart';

void main() {
  test('toJson/fromJson 라운드트립으로 모든 필드가 보존된다', () {
    final draft = CommunityDraft(
      id: 7,
      boardTeamId: 39,
      editPostId: 12,
      title: '제목',
      blocksJson: '[{"type":"text","text":"본문"}]',
      existingImageUrls: const ['https://cdn/a.jpg'],
      savedAt: DateTime.utc(2026, 8, 31, 10, 0),
    );

    final restored = CommunityDraft.fromJson(draft.toJson());

    expect(restored.id, 7);
    expect(restored.boardTeamId, 39);
    expect(restored.editPostId, 12);
    expect(restored.title, '제목');
    expect(restored.blocksJson, '[{"type":"text","text":"본문"}]');
    expect(restored.existingImageUrls, ['https://cdn/a.jpg']);
    expect(restored.savedAt, DateTime.utc(2026, 8, 31, 10, 0));
  });

  test('id·editPostId·existingImageUrls 없이도 fromJson 이 안전하게 채운다', () {
    final restored = CommunityDraft.fromJson({
      'title': '제목만',
      'blocksJson': '[]',
      'savedAt': DateTime.utc(2026, 8, 31).toIso8601String(),
    });

    expect(restored.id, isNull);
    expect(restored.editPostId, isNull);
    expect(restored.boardTeamId, isNull);
    expect(restored.existingImageUrls, isEmpty);
  });

  test('copyWith(id:) 는 id 만 바꾸고 나머지는 그대로 둔다', () {
    final draft = CommunityDraft(
      boardTeamId: null,
      title: '제목',
      blocksJson: '[]',
      savedAt: DateTime.utc(2026, 8, 31),
    );

    final withId = draft.copyWith(id: 3);

    expect(withId.id, 3);
    expect(withId.title, '제목');
    expect(withId.savedAt, draft.savedAt);
  });
}
