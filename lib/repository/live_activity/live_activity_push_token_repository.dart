import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';

/// 실시간 경기 카드 푸시 토큰 등록 API (`/api/mobile/me/live-activities`).
///
/// 서버가 세트 시작·종료 시 이 토큰으로 APNs 를 직접 쏴 카드를 갱신한다.
/// 토큰은 기기가 아니라 카드 하나에 붙고, 카드가 끝나면 서버가 정리하므로
/// 여기서는 등록만 한다.
class LiveActivityPushTokenRepository {
  LiveActivityPushTokenRepository._();
  static final LiveActivityPushTokenRepository instance =
      LiveActivityPushTokenRepository._();

  final AuthService _auth = AuthService.instance;

  /// 카드가 발급한 푸시 토큰을 서버에 올린다. 비회원(토큰 없음)이면 건너뛴다.
  Future<void> register({
    required String matchId,
    required String pushToken,
  }) async {
    try {
      final response = await _auth.authorizedRequest(
        (token) => http.post(
          Uri.parse(ApiConfig.liveActivitiesUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'matchId': matchId, 'pushToken': pushToken}),
        ),
      );
      debugPrint('[LiveActivity] 푸시 토큰 등록 → $matchId ← ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        SentryLogger.warning(
          module: 'API',
          eventName: 'postLiveActivityToken',
          reason: 'status_${response.statusCode}',
          extra: {
            'endpoint': ApiConfig.liveActivitiesUrl,
            'statusCode': response.statusCode,
            'matchId': matchId,
          },
        );
      }
    } catch (e) {
      // 비회원은 authorizedRequest 가 예외를 던진다 — 카드는 폴링으로도
      // 동작하니 등록 실패가 표시 자체를 막지 않는다.
      debugPrint('[LiveActivity] 푸시 토큰 등록 실패: $e');
    }
  }
}
