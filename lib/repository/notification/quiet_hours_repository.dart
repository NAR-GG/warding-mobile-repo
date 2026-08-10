import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/quiet_hours.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// 알림 잠자기 설정 API (`/api/mobile/me/quiet-hours`).
///
/// 인증이 필요하다. [AuthService.authorizedRequest] 로 감싸 Access Token 을 싣고,
/// 만료 시 Refresh Token 으로 자동 갱신·재시도한다.
class QuietHoursRepository {
  QuietHoursRepository._();
  static final QuietHoursRepository instance = QuietHoursRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// 내 잠자기 설정을 조회한다.
  Future<QuietHours> fetch() async {
    final response = await _auth.authorizedRequest(
      (token) => http.get(
        Uri.parse(ApiConfig.quietHoursUrl),
        headers: _headers(token),
      ),
    );
    debugPrint('[QuietHours] 조회 ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('알림 잠자기 조회 실패 (${response.statusCode})');
    }
    return QuietHours.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// 잠자기 설정을 저장한다. 서버가 세 필드를 모두 요구하므로 항상 전체를 보낸다.
  ///
  /// 시작 == 종료거나 분이 5의 배수가 아니면 서버가 400 을 준다.
  Future<QuietHours> update(QuietHours settings) async {
    final response = await _auth.authorizedRequest(
      (token) => http.put(
        Uri.parse(ApiConfig.quietHoursUrl),
        headers: _headers(token),
        body: jsonEncode(settings.toJson()),
      ),
    );
    debugPrint('[QuietHours] 저장 → ${settings.toJson()} ← ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      SentryLogger.warning(
        module: 'API',
        eventName: 'putQuietHours',
        reason: 'status_${response.statusCode}',
        extra: {
          'endpoint': ApiConfig.quietHoursUrl,
          'statusCode': response.statusCode,
        },
      );
      throw Exception('알림 잠자기 설정 변경 실패 (${response.statusCode})');
    }
    return QuietHours.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
