import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../repository/community/community_api_exception.dart';
import '../../repository/community/community_image_repository.dart';
import '../../repository/community/community_repository.dart';

/// 글쓰기 상태·로직 — 사진 선택/업로드와 등록.
///
/// 제목·본문은 [TextEditingController] 가 View 에 남는다(입력 위젯의 상태다).
/// 여기서는 화면이 알아야 하는 것 — 사진 목록, 전송 중 여부, 실패 사유만 든다.
class PostWriteViewModel extends ChangeNotifier {
  PostWriteViewModel({
    required this.boardTeamId,
    CommunityRepository? repository,
    CommunityImageRepository? imageRepository,
    ImagePicker? picker,
  }) : _repository = repository ?? CommunityRepository.instance,
       _images = imageRepository ?? CommunityImageRepository.instance,
       _picker = picker ?? ImagePicker();

  /// null 이면 전체 게시판.
  final int? boardTeamId;

  final CommunityRepository _repository;
  final CommunityImageRepository _images;
  final ImagePicker _picker;

  static const int maxPhotos = 5;

  /// 선택한 사진의 **로컬 경로**. 등록할 때 한꺼번에 업로드해 URL 로 바꾼다 —
  /// 고를 때마다 올리면 글을 안 쓰고 나간 사용자의 사진이 서버에 남는다.
  final List<String> _photos = [];
  List<String> get photos => List.unmodifiable(_photos);

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
    final remaining = maxPhotos - _photos.length;
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
      _photos.addAll(picked.take(remaining).map((x) => x.path));
      _safeNotify();
    } on Exception catch (e) {
      // 취소는 빈 목록으로 오므로 여기 오는 건 진짜 실패뿐이다.
      debugPrint('[PostWriteVM] pick failed: $e');
    }
  }

  void removePhoto(int index) {
    if (index < 0 || index >= _photos.length) return;
    _photos.removeAt(index);
    _safeNotify();
  }

  /// 등록. 성공하면 새 글 id, 실패하면 null 을 주고 [error] 에 사유를 담는다.
  Future<int?> submit({required String title, required String body}) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    _safeNotify();
    try {
      // 직렬로 올리면 5장이 업로드 5번을 줄줄이 기다린다(장당 서명 발급 1회까지 앞에 붙는다).
      // Future.wait 는 입력 순서를 보존하므로 사진 순서가 그대로 유지된다.
      // 한 장이라도 실패하면 전체가 throw 되어 아래 catch 로 떨어진다 — 사진이 빠진 채
      // 글만 올라가는 것보다 낫다.
      final urls = await Future.wait(
        _photos.map((path) => _images.upload(File(path))),
      );
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
