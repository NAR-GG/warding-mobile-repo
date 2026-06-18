import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// 프로필 이미지 업로드 — Firebase Storage 의 `profiles/` 아래에 저장하고
/// 다운로드 URL 을 돌려준다. 그 URL 을 `PUT /api/auth/me` 의
/// `profileImageUrl` 필드에 실어 보낸다.
class ProfileImageRepository {
  ProfileImageRepository._();
  static final ProfileImageRepository instance = ProfileImageRepository._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 같은 userId 라도 캐시 무효화를 위해 timestamp 를 경로에 포함한다.
  Future<String> upload({required int userId, required File file}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('profiles/${userId}_$timestamp.jpg');
    debugPrint('[ProfileImage] uploading → ${ref.fullPath}');
    final snapshot = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await snapshot.ref.getDownloadURL();
    debugPrint('[ProfileImage] uploaded ✓ $url');
    return url;
  }
}
