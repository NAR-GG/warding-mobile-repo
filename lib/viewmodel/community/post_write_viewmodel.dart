import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../model/community_post_block.dart';
import '../../repository/community/community_api_exception.dart';
import '../../repository/community/community_image_repository.dart';
import '../../repository/community/community_repository.dart';

/// 블록 에디터의 블록 하나(전송 전 초안). image 는 [localPath](새 사진, 선업로드
/// 진행 중) 또는 [url](수정 모드의 기존 사진) 중 하나를 든다 — 전송 때
/// [PostWriteViewModel.submitBlocks] 가 localPath 를 업로드 URL 로 치환한다.
class DraftBlock {
  const DraftBlock.text(this.text, {this.heading = false})
    : type = 'text',
      localPath = null,
      url = null,
      title = null,
      description = null,
      imageUrl = null,
      siteName = null,
      provider = null;

  const DraftBlock.image({this.localPath, this.url})
    : type = 'image',
      text = null,
      heading = false,
      title = null,
      description = null,
      imageUrl = null,
      siteName = null,
      provider = null;

  const DraftBlock.link({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  }) : type = 'link',
       text = null,
       heading = false,
       localPath = null,
       provider = null;

  const DraftBlock.embed({required this.provider, required this.url})
    : type = 'embed',
      text = null,
      heading = false,
      localPath = null,
      title = null,
      description = null,
      imageUrl = null,
      siteName = null;

  final String type;
  final String? text;
  final bool heading;
  final String? localPath;
  final String? url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? provider;
}

/// 글쓰기 상태·로직 — 사진 선택/업로드와 등록.
///
/// 제목·본문은 [TextEditingController] 가 View 에 남는다(입력 위젯의 상태다).
/// 여기서는 화면이 알아야 하는 것 — 사진 목록, 전송 중 여부, 실패 사유만 든다.
class PostWriteViewModel extends ChangeNotifier {
  PostWriteViewModel({
    required this.boardTeamId,
    this.editPostId,
    List<String> initialImageUrls = const [],
    CommunityRepository? repository,
    CommunityImageRepository? imageRepository,
    ImagePicker? picker,
  }) : _existingUrls = List.of(initialImageUrls),
       _repository = repository ?? CommunityRepository.instance,
       _images = imageRepository ?? CommunityImageRepository.instance,
       _picker = picker ?? ImagePicker();

  /// null 이면 전체 게시판.
  final int? boardTeamId;

  /// 수정 모드면 대상 글 id, 새 글이면 null.
  final int? editPostId;

  /// 수정 모드에서 글에 이미 붙어 있던 사진 URL. 화면에는 새 사진 앞에 그려지고,
  /// 지우면 최종 imageUrls 에서 빠진다(서버의 전체 교체 계약).
  final List<String> _existingUrls;
  List<String> get existingImageUrls => List.unmodifiable(_existingUrls);

  void removeExistingImage(int index) {
    if (index < 0 || index >= _existingUrls.length) return;
    _existingUrls.removeAt(index);
    _safeNotify();
  }

  final CommunityRepository _repository;
  final CommunityImageRepository _images;
  final ImagePicker _picker;

  static const int maxPhotos = 5;

  /// 선택한 사진의 **로컬 경로**. 순서가 곧 첨부 순서다.
  final List<String> _photos = [];
  List<String> get photos => List.unmodifiable(_photos);

  /// 경로별 **선업로드** Future. 사진을 고르는 순간 업로드를 시작해 두면, 유저가
  /// 제목·본문을 쓰는 동안 업로드가 끝나 등록 버튼은 createPost 한 방만 남는다
  /// (docs/community-photo-preupload-request.md — Cloudinary 왕복이 장당 1초대라
  /// 등록 시점에 올리면 그대로 체감된다. 인스타·트위터가 쓰는 패턴).
  /// 글을 안 쓰고 나가면 Cloudinary 에 고아 파일이 남는데, 지금 규모에선 감수한다.
  final Map<String, Future<String>> _uploads = {};

  bool _submitting = false;
  bool get submitting => _submitting;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> pickPhotos() async {
    final remaining = maxPhotos - _existingUrls.length - _photos.length;
    if (remaining <= 0) return;
    try {
      // maxWidth 가 없으면 아이폰 원본(4032×3024, q85 여도 2~4MB)이 그대로 올라간다.
      // 상세에서 폭 400 남짓으로 그리는 사진이라 1600 이면 확대해서 봐도 충분하고,
      // 파일 크기는 한 자릿수 분의 일이 된다 — 업로드 시간·Cloudinary 저장 용량이 같이 준다.
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        limit: remaining,
      );
      if (picked.isEmpty) return;
      for (final x in picked.take(remaining)) {
        _photos.add(x.path);
        _startUpload(x.path); // 고르는 즉시 선업로드
      }
      _safeNotify();
    } on Exception catch (e) {
      // 취소는 빈 목록으로 오므로 여기 오는 건 진짜 실패뿐이다.
      debugPrint('[PostWriteVM] pick failed: $e');
    }
  }

  /// 업로드를 시작하고 맵에 건다. 실패하면 맵에서 스스로 빠져 다음 submit 때
  /// 재업로드된다 — 실패 Future 가 남아 있으면 영영 같은 에러만 다시 받는다.
  /// 여기 붙인 onError 리스너가 "unhandled async error" 경고도 막아 주고,
  /// submit 쪽 await 리스너는 에러를 그대로 받는다(전체 실패 정책 유지).
  Future<String> _startUpload(String path) {
    final upload = _images.upload(File(path));
    _uploads[path] = upload;
    upload.then<void>((_) {}, onError: (Object _) {
      if (identical(_uploads[path], upload)) _uploads.remove(path);
    });
    return upload;
  }

  void removePhoto(int index) {
    if (index < 0 || index >= _photos.length) return;
    final path = _photos.removeAt(index);
    // 업로드 취소까지는 불필요 — 결과 URL 을 안 쓰면 그만이다.
    _uploads.remove(path);
    _safeNotify();
  }

  /// 블록 에디터용 사진 선택. 고른 즉시 선업로드를 걸고 **로컬 경로 목록**을
  /// 돌려준다 — 사진 스트립([photos])에는 넣지 않는다. 블록이 위치의 진실이라
  /// 화면이 경로로 image 블록을 만든다. [remaining] 은 남은 첨부 가능 장수.
  Future<List<String>> pickPhotosForBlocks(int remaining) async {
    if (remaining <= 0) return const [];
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        limit: remaining,
      );
      final paths = [for (final x in picked.take(remaining)) x.path];
      for (final path in paths) {
        _startUpload(path);
      }
      return paths;
    } on Exception catch (e) {
      debugPrint('[PostWriteVM] pick failed: $e');
      return const [];
    }
  }

  /// 링크 프리뷰. 실패해도 throw 하지 않는다 — 프리뷰 없는 맨 링크 카드가 폴백이다.
  Future<CommunityLinkPreview> fetchLinkPreview(String url) async {
    try {
      return await _repository.fetchLinkPreview(url);
    } catch (e) {
      debugPrint('[PostWriteVM] link-preview failed: $e');
      return CommunityLinkPreview(url: url);
    }
  }

  /// 블록 본문 등록/수정(bodyFormat=BLOCKS). 성공하면 글 id, 실패하면 null +
  /// [error]. 새 사진(localPath)은 선업로드 결과를 기다렸다가 URL 로 치환한다.
  Future<int?> submitBlocks({
    required String title,
    required List<DraftBlock> blocks,
    ({String question, List<String> options})? poll,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    _safeNotify();
    try {
      final resolved = <CommunityPostBlock>[];
      for (final block in blocks) {
        switch (block.type) {
          case 'text':
            final text = block.text?.trim() ?? '';
            if (text.isEmpty) continue; // 빈 텍스트 블록은 버린다
            resolved.add(CommunityPostBlock(
              type: 'text',
              text: text,
              style: block.heading ? 'heading' : 'body',
            ));
          case 'image':
            final path = block.localPath;
            final url = path != null
                ? await (_uploads[path] ?? _startUpload(path))
                : block.url;
            if (url == null) continue;
            resolved.add(CommunityPostBlock(type: 'image', url: url));
          case 'link':
            resolved.add(CommunityPostBlock(
              type: 'link',
              url: block.url,
              title: block.title,
              description: block.description,
              imageUrl: block.imageUrl,
              siteName: block.siteName,
            ));
          case 'embed':
            resolved.add(CommunityPostBlock(
              type: 'embed',
              provider: block.provider,
              url: block.url,
            ));
        }
      }
      final body = CommunityPostBlock.encodeList(resolved);
      final editId = editPostId;
      if (editId != null) {
        await _repository.updatePost(
          editId,
          boardTeamId: boardTeamId,
          title: title.trim(),
          body: body,
          bodyFormat: 'BLOCKS',
        );
        return editId;
      }
      return await _repository.createPost(
        boardTeamId: boardTeamId,
        title: title.trim(),
        body: body,
        bodyFormat: 'BLOCKS',
        poll: poll, // 수정 모드에는 없다 — 투표는 작성 시에만 붙는다(서버 계약)
      );
    } catch (e) {
      debugPrint('[PostWriteVM] submitBlocks failed: $e');
      _error = e is CommunityApiException
          ? e.message
          : (appStrings?.communityWriteFailed ?? 'Failed to post');
      return null;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  /// 등록/수정. 성공하면 글 id, 실패하면 null 을 주고 [error] 에 사유를 담는다.
  Future<int?> submit({required String title, required String body}) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    _safeNotify();
    try {
      // 선업로드가 이미 돌고 있으므로 보통 여기서는 기다릴 게 없다. 아직 안 끝난
      // 장만 마저 기다린다(Future.wait 는 입력 순서를 보존해 사진 순서가 유지된다).
      // 한 장이라도 실패하면 전체가 throw 되어 아래 catch 로 떨어진다 — 사진이 빠진 채
      // 글만 올라가는 것보다 낫다. 실패한 장은 다음 submit 에서 재업로드된다.
      final uploaded = await Future.wait(
        // 선업로드가 실패해 맵에서 빠진 장은 여기서 재업로드된다.
        _photos.map((path) => _uploads[path] ?? _startUpload(path)),
      );
      // 남긴 기존 사진 뒤에 새 사진 — 서버 imageUrls 는 전체 교체 계약이다.
      final urls = [..._existingUrls, ...uploaded];
      final editId = editPostId;
      if (editId != null) {
        await _repository.updatePost(
          editId,
          boardTeamId: boardTeamId,
          title: title.trim(),
          body: body.trim(),
          imageUrls: urls,
        );
        return editId;
      }
      return await _repository.createPost(
        boardTeamId: boardTeamId,
        title: title.trim(),
        body: body.trim(),
        imageUrls: urls,
      );
    } catch (e) {
      debugPrint('[PostWriteVM] submit failed: $e');
      _error = e is CommunityApiException
          ? e.message
          : (appStrings?.communityWriteFailed ?? 'Failed to post');
      return null;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }
}
