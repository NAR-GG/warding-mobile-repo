import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:warding/repository/community/community_api_exception.dart';

void main() {
  test('code·message·Retry-After 헤더를 파싱한다', () {
    final jsonBody =
        '{"timestamp":"2026-08-28T00:00:00","status":403,"error":"FORBIDDEN",'
        '"code":"COMMUNITY_TEAM_COOLDOWN","message":"응원팀을 바꾼 지 얼마 되지 않았습니다."}';
    final response = http.Response.bytes(
      utf8.encode(jsonBody),
      403,
      headers: {
        'retry-after': '86400',
        'content-type': 'application/json; charset=utf-8',
      },
    );

    final exception = CommunityApiException.fromResponse(response);

    expect(exception.statusCode, 403);
    expect(exception.code, 'COMMUNITY_TEAM_COOLDOWN');
    expect(exception.message, '응원팀을 바꾼 지 얼마 되지 않았습니다.');
    expect(exception.retryAfterSeconds, 86400);
  });

  test('Retry-After 헤더가 없으면 null', () {
    final jsonBody = '{"code":"COMMUNITY_BOARD_FORBIDDEN","message":"권한이 없습니다."}';
    final response = http.Response.bytes(
      utf8.encode(jsonBody),
      403,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    final exception = CommunityApiException.fromResponse(response);

    expect(exception.retryAfterSeconds, isNull);
  });

  test('본문이 JSON이 아니면 code는 null, message는 HTTP 상태코드로 대체', () {
    final response = http.Response('<html>Bad Gateway</html>', 502);

    final exception = CommunityApiException.fromResponse(response);

    expect(exception.code, isNull);
    expect(exception.message, 'HTTP 502');
  });
}
