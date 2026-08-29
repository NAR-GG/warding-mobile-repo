import 'dart:convert';

import '../../util/api_client.dart' as http;

import '../../config/api_config.dart';
import '../../model/community_report.dart';
import '../../util/sentry_logger.dart';
import '../auth/auth_service.dart';
import 'community_api_exception.dart';

/// 커뮤니티 신고·차단 API (`/api/mobile/community/reports`, `/blocks`).
/// 전부 인증이 필요하다.
class CommunityReportRepository {
  CommunityReportRepository._();
  static final CommunityReportRepository instance =
      CommunityReportRepository._();

  final AuthService _auth = AuthService.instance;

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  void _checkOk(http.Response response, String eventName) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final exception = CommunityApiException.fromResponse(response);
      SentryLogger.warning(
        module: 'API',
        eventName: eventName,
        reason: 'status_${response.statusCode}',
        extra: {'statusCode': response.statusCode, 'code': exception.code},
      );
      throw exception;
    }
  }

  /// 글·댓글·이미지를 신고한다. 같은 대상 재신고는 409
  /// ([CommunityApiException.statusCode]) — "이미 신고했습니다" 처리는
  /// 호출부 몫. [reason]이 [CommunityReportReason.etc]면 [detail](≤200자) 필수.
  Future<void> report({
    required CommunityReportTargetType targetType,
    required int targetId,
    required CommunityReportReason reason,
    String? detail,
  }) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityReportsUrl),
        headers: _headers(token),
        body: jsonEncode({
          'targetType': targetType.apiValue,
          'targetId': targetId,
          'reason': reason.apiValue,
          'detail': detail,
        }),
      ),
    );
    _checkOk(response, 'reportCommunityTarget');
  }

  /// 사용자를 차단한다. 이미 차단했어도 204(멱등). 자기 자신은 400.
  Future<void> block(int memberId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.post(
        Uri.parse(ApiConfig.communityBlocksUrl),
        headers: _headers(token),
        body: jsonEncode({'memberId': memberId}),
      ),
    );
    _checkOk(response, 'blockCommunityMember');
  }

  /// 차단을 해제한다(멱등).
  Future<void> unblock(int memberId) async {
    final response = await _auth.authorizedRequest(
      (token) => http.delete(
        Uri.parse(ApiConfig.communityBlockUrl(memberId)),
        headers: _headers(token),
      ),
    );
    _checkOk(response, 'unblockCommunityMember');
  }
}
