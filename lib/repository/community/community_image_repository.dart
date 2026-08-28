import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// 커뮤니티 사진 업로드 — 백엔드에서 Cloudinary 서명 파라미터를 발급받아
/// 앱이 Cloudinary로 직접 업로드하고, 받은 `secure_url`을 돌려준다. 이미지
/// 1장 = 서명 1회([ProfileImageRepository]와 달리 `publicId`가 매번 새로
/// 발급된다).
///
/// 흐름: `POST /api/auth/me/community-image/signature`(인증) → Cloudinary
/// `image/upload`(multipart) → `secure_url`. 받은 URL들을 모아 글 작성/수정
/// API의 `imageUrls`로 보낸다.
class CommunityImageRepository {
  CommunityImageRepository({AuthService? auth})
    : _auth = auth ?? AuthService.instance;

  static final CommunityImageRepository instance = CommunityImageRepository();

  final AuthService _auth;

  /// [file]을 Cloudinary에 업로드하고 `secure_url`을 반환한다.
  Future<String> upload(File file) async {
    final sig = await _fetchSignature();
    return _uploadToCloudinary(sig, file);
  }

  Future<_CommunityImageSignature> _fetchSignature() async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityImageSignatureUrl),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'communityImageSignature',
        reason: 'status_${response.statusCode}',
        extra: {
          'endpoint': ApiConfig.communityImageSignatureUrl,
          'statusCode': response.statusCode,
        },
      );
      throw Exception('커뮤니티 사진 서명 발급 실패 (${response.statusCode})');
    }
    return _CommunityImageSignature.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> _uploadToCloudinary(
    _CommunityImageSignature sig,
    File file,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(sig.uploadUrl))
      ..fields['api_key'] = sig.apiKey
      ..fields['timestamp'] = sig.timestamp.toString()
      ..fields['public_id'] = sig.publicId
      ..fields['overwrite'] = sig.overwrite.toString()
      ..fields['signature'] = sig.signature
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    debugPrint('[CommunityImage] uploading → ${sig.publicId}');
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'communityImageUpload',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': sig.uploadUrl, 'statusCode': response.statusCode},
      );
      throw Exception(
        'Cloudinary 업로드 실패 (${response.statusCode}): ${response.body}',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final url = data['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      SentryLogger.error(
        module: 'Logic',
        eventName: 'communityImageUpload',
        reason: 'missing_secure_url',
        extra: {'publicId': sig.publicId},
      );
      throw Exception('Cloudinary 응답에 secure_url이 없습니다: ${response.body}');
    }
    debugPrint('[CommunityImage] uploaded ✓ $url');
    return url;
  }
}

/// `POST /api/auth/me/community-image/signature` 응답.
class _CommunityImageSignature {
  const _CommunityImageSignature({
    required this.uploadUrl,
    required this.apiKey,
    required this.timestamp,
    required this.publicId,
    required this.overwrite,
    required this.signature,
  });

  final String uploadUrl;
  final String apiKey;
  final int timestamp;
  final String publicId;
  final bool overwrite;
  final String signature;

  factory _CommunityImageSignature.fromJson(Map<String, dynamic> json) {
    return _CommunityImageSignature(
      uploadUrl: json['uploadUrl'] as String,
      apiKey: json['apiKey'] as String,
      timestamp: json['timestamp'] as int,
      publicId: json['publicId'] as String,
      overwrite: json['overwrite'] as bool? ?? false,
      signature: json['signature'] as String,
    );
  }
}
