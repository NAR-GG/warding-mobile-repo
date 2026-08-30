import 'dart:convert';

import '../../util/api_client.dart' as http;

/// 커뮤니티 API가 2xx가 아닐 때 던지는 공통 예외.
///
/// 서버 에러 응답(`{code, message}`)과 `Retry-After` 헤더(초)를 구조화해
/// 담는다. ViewModel은 [code]로 분기해 쿨다운·작성 간격 등 문구를 그린다.
class CommunityApiException implements Exception {
  const CommunityApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.retryAfterSeconds,
  });

  final int statusCode;

  /// 예: `COMMUNITY_TEAM_COOLDOWN`, `COMMUNITY_WRITE_INTERVAL`. 서버가 안 주면 null.
  final String? code;

  final String message;

  /// `Retry-After` 헤더(초). 쿨다운·작성 간격 위반에만 온다.
  final int? retryAfterSeconds;

  factory CommunityApiException.fromResponse(http.Response response) {
    var message = 'HTTP ${response.statusCode}';
    String? code;
    try {
      // response.body 는 Content-Type 에 charset 이 없으면 latin1 로 풀어서
      // 한글 메시지가 ë¡œ… 로 깨진다 — 항상 UTF-8 로 직접 디코딩한다.
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        code = body['code'] as String?;
        message = body['message'] as String? ?? message;
      }
    } catch (_) {
      // 본문이 JSON이 아니면(게이트웨이 에러 페이지 등) 기본 메시지를 쓴다.
    }
    final retryAfter = response.headers['retry-after'];
    return CommunityApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      retryAfterSeconds: retryAfter != null ? int.tryParse(retryAfter) : null,
    );
  }

  @override
  String toString() =>
      'CommunityApiException($statusCode, code=$code, message=$message, '
      'retryAfterSeconds=$retryAfterSeconds)';
}
