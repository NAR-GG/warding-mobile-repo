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
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
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
      final urls = <String>[];
      for (final path in _photos) {
        urls.add(await _images.upload(File(path)));
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
