import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/repository/community/community_image_repository.dart';
import 'package:warding/repository/community/community_repository.dart';
import 'package:warding/viewmodel/community/post_write_viewmodel.dart';

class _MockRepository extends Mock implements CommunityRepository {}

class _MockImages extends Mock implements CommunityImageRepository {}

class _MockPicker extends Mock implements ImagePicker {}

/// 사진 선업로드 — 고르는 순간 업로드가 시작되고, 등록 버튼은 그 결과를 재사용한다.
/// 실패한 장은 맵에서 빠져 다음 등록 시도에서 재업로드된다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // submit 실패 문구가 l10n(appStrings)을 만진다

  setUpAll(() {
    registerFallbackValue(File('fallback'));
  });

  late _MockRepository repository;
  late _MockImages images;
  late _MockPicker picker;
  late PostWriteViewModel viewModel;

  /// 경로별 upload 호출 횟수. 재사용/재시도 검증의 근거.
  late Map<String, int> uploadCalls;

  void servePick(List<String> paths) {
    when(
      () => picker.pickMultiImage(
        imageQuality: any(named: 'imageQuality'),
        maxWidth: any(named: 'maxWidth'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => paths.map(XFile.new).toList());
  }

  void serveUpload({Set<String> failOnFirstCall = const {}}) {
    when(() => images.upload(any())).thenAnswer((invocation) async {
      final path = (invocation.positionalArguments[0] as File).path;
      final calls = uploadCalls[path] = (uploadCalls[path] ?? 0) + 1;
      if (calls == 1 && failOnFirstCall.contains(path)) {
        throw Exception('upload failed: $path');
      }
      return 'https://cdn/$path';
    });
  }

  setUp(() {
    repository = _MockRepository();
    images = _MockImages();
    picker = _MockPicker();
    uploadCalls = {};
    viewModel = PostWriteViewModel(
      boardTeamId: null,
      repository: repository,
      imageRepository: images,
      picker: picker,
    );
    when(
      () => repository.createPost(
        boardTeamId: any(named: 'boardTeamId'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        imageUrls: any(named: 'imageUrls'),
      ),
    ).thenAnswer((_) async => 42);
  });

  test('사진을 고르는 순간 업로드가 시작된다', () async {
    serveUpload();
    servePick(['a.jpg', 'b.jpg']);

    await viewModel.pickPhotos();
    await Future<void>.delayed(Duration.zero);

    expect(uploadCalls, {'a.jpg': 1, 'b.jpg': 1}); // submit 전에 이미 올라갔다
  });

  test('등록은 선업로드 결과를 재사용하고 순서를 지킨다', () async {
    serveUpload();
    servePick(['a.jpg', 'b.jpg']);
    await viewModel.pickPhotos();

    final id = await viewModel.submit(title: '제목', body: '본문');

    expect(id, 42);
    expect(uploadCalls, {'a.jpg': 1, 'b.jpg': 1}); // 재업로드 없음
    verify(
      () => repository.createPost(
        boardTeamId: null,
        title: '제목',
        body: '본문',
        imageUrls: ['https://cdn/a.jpg', 'https://cdn/b.jpg'],
      ),
    ).called(1);
  });

  test('삭제한 사진의 URL 은 등록에 안 들어간다', () async {
    serveUpload();
    servePick(['a.jpg', 'b.jpg']);
    await viewModel.pickPhotos();

    viewModel.removePhoto(0);
    await viewModel.submit(title: '제목', body: '본문');

    verify(
      () => repository.createPost(
        boardTeamId: null,
        title: '제목',
        body: '본문',
        imageUrls: ['https://cdn/b.jpg'],
      ),
    ).called(1);
  });

  test('등록 도중 업로드가 실패하면 전체 실패하고, 다음 등록에서 재업로드된다', () async {
    // 1차 업로드는 손으로 완료시키는 Completer — submit 이 기다리는 도중에 실패시킨다.
    final firstTry = Completer<String>();
    var calls = 0;
    when(() => images.upload(any())).thenAnswer((_) {
      calls++;
      return calls == 1 ? firstTry.future : Future.value('https://cdn/retry');
    });
    servePick(['a.jpg']);
    await viewModel.pickPhotos();

    // 1차 등록: 업로드 실패가 전파돼 전체 실패 (사진 빠진 글 방지 정책)
    final submitFuture = viewModel.submit(title: '제목', body: '본문');
    firstTry.completeError(Exception('upload boom'));
    expect(await submitFuture, isNull);
    expect(viewModel.error, isNotNull);

    // 2차 등록: 실패 장이 맵에서 빠져 있어 재업로드 → 성공
    final second = await viewModel.submit(title: '제목', body: '본문');
    expect(second, 42);
    expect(calls, 2);
  });
}
