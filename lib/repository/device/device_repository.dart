import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// FCM 기기 토큰 관리 API (`/api/mobile/me/devices`).
///
/// 인증이 필요하므로 [AuthService] 의 JWT 를 헤더에 싣는다.
/// 서버가 돌려준 `deviceId` 는 로그아웃 시 기기 비활성화에 쓰려고 보관한다.
class DeviceRepository {
  DeviceRepository._();
  static final DeviceRepository instance = DeviceRepository._();

  static const _deviceIdKey = 'fcm_device_id';

  final AuthService _auth = AuthService.instance;
  final _storage = const FlutterSecureStorage();

  /// 마지막으로 등록해 받은 기기 ID. 없으면 null.
  Future<String?> get deviceId => _storage.read(key: _deviceIdKey);

  /// FCM 토큰을 등록하거나 갱신한다. 응답의 `deviceId` 를 저장한다.
  /// 로그인(JWT) 상태가 아니면 조용히 건너뛴다.
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
  }) async {
    final jwt = await _auth.jwt;
    if (jwt == null || jwt.isEmpty) {
      debugPrint('[Device] 비로그인 상태 — 토큰 등록 생략');
      return;
    }
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.devicesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'fcmToken': fcmToken, 'platform': platform}),
      ),
    );
    debugPrint('[Device] 등록 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'registerDevice',
        reason: 'status_${response.statusCode}',
        extra: {'endpoint': ApiConfig.devicesUrl, 'statusCode': response.statusCode, 'platform': platform},
      );
      throw Exception('기기 토큰 등록 실패 (${response.statusCode})');
    }
    // 응답에 deviceId 가 있으면 보관한다.
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final id = data['deviceId'];
      if (id != null) {
        await _storage.write(key: _deviceIdKey, value: id.toString());
      }
    } catch (_) {
      // 응답 본문이 비었거나 형식이 달라도 등록 자체는 성공으로 본다.
    }
    SentryLogger.info(module: 'API', eventName: 'registerDevice', extra: {'platform': platform});
  }

  /// 보관 중인 기기를 비활성화한다 (로그아웃 등). deviceId 가 없으면 아무것도 안 한다.
  Future<void> deactivateDevice() async {
    final id = await deviceId;
    if (id == null || id.isEmpty) return;
    final jwt = await _auth.jwt;
    if (jwt != null && jwt.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse(ApiConfig.deviceUrl(id)),
          headers: {'Authorization': 'Bearer $jwt'},
        );
      } catch (e) {
        debugPrint('[Device] 비활성화 실패(무시): $e');
      }
    }
    await _storage.delete(key: _deviceIdKey);
  }
}
