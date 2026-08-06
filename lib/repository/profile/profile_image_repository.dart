import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// 프로필 이미지 업로드 — 백엔드에서 Cloudinary 서명 파라미터를 발급받아
/// 앱이 Cloudinary 로 직접 업로드하고, 받은 `secure_url` 을 돌려준다.
/// 그 URL 을 `PUT /api/auth/me` 의 `profileImageUrl` 로 저장한다.
///
/// 흐름: `POST /api/auth/me/profile-image/signature`(인증) →
/// Cloudinary `image/upload`(multipart) → `secure_url`.
class ProfileImageRepository {
  ProfileImageRepository({AuthService? auth})
      : _auth = auth ?? AuthService.instance;

  static final ProfileImageRepository instance = ProfileImageRepository();

  final AuthService _auth;

  /// [file] 을 Cloudinary 에 업로드하고 `secure_url` 을 반환한다.
  Future<String> upload(File file) async {
    final sig = await _fetchSignature();
    return _uploadToCloudinary(sig, file);
  }

  /// 백엔드에서 서명 파라미터를 발급받는다(인증 필요).
  Future<_CloudinarySignature> _fetchSignature() async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.profileImageSignatureUrl),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'updateProfile',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.profileImageSignatureUrl, 'statusCode': response.statusCode, 'step': 'fetchSignature'},
      );
      throw Exception('프로필 이미지 서명 발급 실패 (${response.statusCode})');
    }
    return _CloudinarySignature.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 발급받은 서명 그대로 Cloudinary 에 multipart 업로드한다.
  /// 서명에 포함된 파라미터(timestamp·public_id·overwrite)를 그대로 보내야
  /// 서명이 검증되므로 임의 필드를 추가하지 않는다.
  Future<String> _uploadToCloudinary(
    _CloudinarySignature sig,
    File file,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse(sig.uploadUrl))
      ..fields['api_key'] = sig.apiKey
      ..fields['timestamp'] = sig.timestamp.toString()
      ..fields['public_id'] = sig.publicId
      ..fields['overwrite'] = sig.overwrite.toString()
      ..fields['signature'] = sig.signature
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    debugPrint('[ProfileImage] uploading → ${sig.publicId}');
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'updateProfile',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': sig.uploadUrl, 'statusCode': response.statusCode, 'step': 'cloudinaryUpload'},
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
        eventName: 'updateProfile',
        reason: 'missing_secure_url',
        extra: {'step': 'cloudinaryUpload', 'publicId': sig.publicId},
      );
      throw Exception('Cloudinary 응답에 secure_url 이 없습니다: ${response.body}');
    }
    debugPrint('[ProfileImage] uploaded ✓ $url');
    SentryLogger.info(module: 'API', eventName: 'updateProfile', extra: {'publicId': sig.publicId});
    return url;
  }
}

/// `POST /api/auth/me/profile-image/signature` 응답.
class _CloudinarySignature {
  const _CloudinarySignature({
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

  factory _CloudinarySignature.fromJson(Map<String, dynamic> json) {
    return _CloudinarySignature(
      uploadUrl: json['uploadUrl'] as String,
      apiKey: json['apiKey'] as String,
      timestamp: json['timestamp'] as int,
      publicId: json['publicId'] as String,
      overwrite: json['overwrite'] as bool? ?? true,
      signature: json['signature'] as String,
    );
  }
}
