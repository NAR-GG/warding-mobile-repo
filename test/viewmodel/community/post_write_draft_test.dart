import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/community_draft.dart';
import 'package:warding/repository/community/community_draft_repository.dart';
import 'package:warding/repository/community/community_image_repository.dart';
import 'package:warding/repository/community/community_repository.dart';
import 'package:warding/viewmodel/community/post_write_viewmodel.dart';

class _MockRepository extends Mock implements CommunityRepository {}

class _MockImages extends Mock implements CommunityImageRepository {}

class _MockPicker extends Mock implements ImagePicker {}

class _MockDraftRepository extends Mock implements CommunityDraftRepository {}

CommunityDraft _draft({int? id, String title = '제목'}) => CommunityDraft(
  id: id,
  boardTeamId: null,
  title: title,
  blocksJson: '[]',
  savedAt: DateTime.utc(2026, 8, 31),
);

/// 임시저장 — 여러 글을 로컬에 보관하고, 불러올 때 로컬 사진은 다시 선업로드를 건다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(File('fallback'));
    registerFallbackValue(_draft());
  });

  late _MockRepository repository;
  late _MockImages images;
  late _MockPicker picker;
  late _MockDraftRepository drafts;
  late PostWriteViewModel viewModel;

  setUp(() {
    repository = _MockRepository();
    images = _MockImages();
    picker = _MockPicker();
    drafts = _MockDraftRepository();
    viewModel = PostWriteViewModel(
      boardTeamId: 39,
      editPostId: 12,
      repository: repository,
      imageRepository: images,
      picker: picker,
      draftRepository: drafts,
    );
  });

  test('saveDraft: 새 드래프트를 저장하면 목록 맨 앞에 반영된다', () async {
    when(() => drafts.save(any())).thenAnswer(
      (invocation) async =>
          (invocation.positionalArguments[0] as CommunityDraft).copyWith(id: 1),
    );

    final saved = await viewModel.saveDraft(
      title: '제목',
      blocks: const [DraftBlock.text('본문')],
    );

    expect(saved.id, 1);
    expect(viewModel.draftCount, 1);
    expect(viewModel.drafts.single.title, '제목');

    final sentDraft =
        verify(() => drafts.save(captureAny())).captured.single
            as CommunityDraft;
    expect(sentDraft.boardTeamId, 39);
    expect(sentDraft.editPostId, 12);
  });

  test('saveDraft: 같은 draftId 로 다시 저장하면 개수는 그대로고 최신 내용으로 갱신된다', () async {
    when(() => drafts.save(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments[0] as CommunityDraft,
    );
    await viewModel.saveDraft(
      title: '첫 저장',
      blocks: const [DraftBlock.text('본문')],
      draftId: 5,
    );

    await viewModel.saveDraft(
      title: '수정된 저장',
      blocks: const [DraftBlock.text('본문2')],
      draftId: 5,
    );

    expect(viewModel.draftCount, 1);
    expect(viewModel.drafts.single.title, '수정된 저장');
  });

  test('refreshDrafts 후 saveDraft: 저장소가 불변 빈 목록(const [])을 줘도 저장이 된다', () async {
    // CommunityDraftRepository.loadAll()은 저장값이 없을 때 const [] 를 준다.
    // refreshDrafts 가 그걸 그대로 _drafts 에 대입하면, 다음 saveDraft 의
    // removeWhere 가 불변 리스트를 건드려 던진다(실제 버그 재현).
    when(() => drafts.loadAll()).thenAnswer((_) async => const []);
    when(() => drafts.save(any())).thenAnswer(
      (invocation) async =>
          (invocation.positionalArguments[0] as CommunityDraft).copyWith(id: 1),
    );
    await viewModel.refreshDrafts();

    await viewModel.saveDraft(
      title: '제목',
      blocks: const [DraftBlock.text('본문')],
    );

    expect(viewModel.draftCount, 1);
  });

  test('refreshDrafts: 저장소의 목록을 그대로 읽어온다', () async {
    when(
      () => drafts.loadAll(),
    ).thenAnswer((_) async => [_draft(id: 1), _draft(id: 2)]);

    await viewModel.refreshDrafts();

    expect(viewModel.draftCount, 2);
  });

  test('deleteDraft: 저장소에서 지우고 로컬 목록에서도 뺀다', () async {
    when(
      () => drafts.loadAll(),
    ).thenAnswer((_) async => [_draft(id: 1), _draft(id: 2)]);
    when(() => drafts.delete(1)).thenAnswer((_) async {});
    await viewModel.refreshDrafts();

    await viewModel.deleteDraft(1);

    verify(() => drafts.delete(1)).called(1);
    expect(viewModel.drafts.map((d) => d.id), [2]);
  });

  test('resumePreuploads: 존재하는 로컬 파일만 다시 선업로드를 건다', () async {
    final dir = await Directory.systemTemp.createTemp('draft_resume_test');
    final existing = File('${dir.path}/a.jpg')..writeAsStringSync('x');
    final missingPath = '${dir.path}/missing.jpg';
    when(
      () => images.upload(any()),
    ).thenAnswer((_) async => 'https://cdn/resumed');

    viewModel.resumePreuploads([existing.path, missingPath]);
    await Future<void>.delayed(Duration.zero);

    final uploadedPaths = verify(() => images.upload(captureAny()))
        .captured
        .cast<File>()
        .map((f) => f.path)
        .toList();
    expect(uploadedPaths, [existing.path]);

    await dir.delete(recursive: true);
  });
}
