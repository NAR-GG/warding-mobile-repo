import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/community_draft.dart';
import 'package:warding/repository/community/community_draft_repository.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

CommunityDraft _draft({int? id, String title = '제목'}) => CommunityDraft(
  id: id,
  boardTeamId: null,
  title: title,
  blocksJson: '[]',
  savedAt: DateTime.utc(2026, 8, 31),
);

void main() {
  late MockSecureStorage storage;
  late CommunityDraftRepository repo;

  setUp(() {
    storage = MockSecureStorage();
    repo = CommunityDraftRepository(storage: storage);
    when(
      () => storage.write(key: any(named: 'key'), value: any(named: 'value')),
    ).thenAnswer((_) async {});
  });

  test('loadAll: 저장값이 없으면 빈 목록', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    expect(await repo.loadAll(), isEmpty);
  });

  test('loadAll: 손상된 JSON 이면 빈 목록으로 폴백한다', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => 'garbage');
    expect(await repo.loadAll(), isEmpty);
  });

  test('loadAll: 저장된 목록을 그대로 복원한다', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => jsonEncode([_draft(id: 1, title: 'a').toJson()]),
    );
    final list = await repo.loadAll();
    expect(list, hasLength(1));
    expect(list.single.title, 'a');
  });

  test('save: 저장값이 아예 없던 첫 저장(빈 목록이 아니라 null)도 성공한다', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);

    final saved = await repo.save(_draft());

    expect(saved.id, isNotNull);
    verify(
      () => storage.write(
        key: 'community_post_drafts',
        value: any(named: 'value'),
      ),
    ).called(1);
  });

  test('save: 새 드래프트는 id 를 채번해 맨 앞에 추가한다', () async {
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => jsonEncode([]));

    final saved = await repo.save(_draft());

    expect(saved.id, isNotNull);
    verify(
      () => storage.write(
        key: 'community_post_drafts',
        value: any(named: 'value'),
      ),
    ).called(1);
  });

  test('save: 같은 id 로 저장하면 개수는 그대로고 내용만 덮어쓴다', () async {
    final existing = [_draft(id: 1, title: '원래 제목')];
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => jsonEncode([for (final d in existing) d.toJson()]),
    );

    await repo.save(_draft(id: 1, title: '수정된 제목'));

    final captured =
        verify(
              () => storage.write(
                key: 'community_post_drafts',
                value: captureAny(named: 'value'),
              ),
            ).captured.single
            as String;
    final list = (jsonDecode(captured) as List)
        .map((e) => CommunityDraft.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(list, hasLength(1));
    expect(list.single.title, '수정된 제목');
  });

  test('save: 수정된 항목은 목록 맨 앞으로 올라온다', () async {
    final existing = [_draft(id: 1, title: '오래된 글'), _draft(id: 2, title: '글2')];
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => jsonEncode([for (final d in existing) d.toJson()]),
    );

    await repo.save(_draft(id: 1, title: '방금 수정'));

    final captured =
        verify(
              () => storage.write(
                key: 'community_post_drafts',
                value: captureAny(named: 'value'),
              ),
            ).captured.single
            as String;
    final list = jsonDecode(captured) as List;
    expect(list.first['title'], '방금 수정');
  });

  test('save: 상한(maxDrafts)을 넘기면 가장 오래된 항목을 버린다', () async {
    final existing = [
      for (var i = 0; i < CommunityDraftRepository.maxDrafts; i++)
        _draft(id: i, title: 'draft $i'),
    ];
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => jsonEncode([for (final d in existing) d.toJson()]),
    );

    await repo.save(_draft(id: 999, title: '새 글'));

    final captured =
        verify(
              () => storage.write(
                key: 'community_post_drafts',
                value: captureAny(named: 'value'),
              ),
            ).captured.single
            as String;
    final list = jsonDecode(captured) as List;
    expect(list, hasLength(CommunityDraftRepository.maxDrafts));
    expect(list.any((e) => e['id'] == (existing.length - 1)), isFalse);
  });

  test('delete: id 로 항목을 지운다', () async {
    final existing = [_draft(id: 1), _draft(id: 2)];
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => jsonEncode([for (final d in existing) d.toJson()]),
    );

    await repo.delete(1);

    final captured =
        verify(
              () => storage.write(
                key: 'community_post_drafts',
                value: captureAny(named: 'value'),
              ),
            ).captured.single
            as String;
    final list = jsonDecode(captured) as List;
    expect(list, hasLength(1));
    expect(list.single['id'], 2);
  });
}
