import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/util/api_client.dart' as api;

/// [AuthService.authorizedRequest] 의 재발급 실패 구분 검증.
///
/// 핵심: 강제 로그아웃(토큰 삭제)은 refresh 요청이 **완료되어 401 을 반환한
/// 경우에만** 일어나야 한다. 타임아웃·네트워크 예외·5xx·429 는 일시 장애라
/// 토큰을 지우면 안 된다 — 2026-08-11 20:17 prod 장애에서 refresh 가 커넥션
/// 풀 대기로 수 초씩 걸리자 유저들이 전부 로그아웃당한 사고의 회귀 테스트.
void main() {
  // _forceLogout 이 navigatorKey.currentState 를 읽으므로 바인딩이 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();

  const jwtKey = 'jwt';
  const refreshKey = 'refreshToken';

  final auth = AuthService.instance;

  /// 만료된 Access Token 으로 보낸 요청을 흉내 내는 send 콜백.
  /// 받은 토큰을 기록해 재시도 여부를 검증할 수 있게 한다.
  final sentTokens = <String>[];
  Future<api.Response> expiredThenOk(String token) async {
    sentTokens.add(token);
    if (token == 'old-jwt') return http.Response('', 401);
    return http.Response('ok', 200);
  }

  setUp(() {
    sentTokens.clear();
    FlutterSecureStorage.setMockInitialValues({
      jwtKey: 'old-jwt',
      refreshKey: 'refresh-1',
    });
  });

  tearDown(() => api.setApiClientForTesting(null));

  /// refresh 엔드포인트(`/api/auth/refresh`)만 [handler] 로 응답하는 클라이언트.
  void mockRefreshEndpoint(
    FutureOr<http.Response> Function(http.Request request) handler,
  ) {
    api.setApiClientForTesting(MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') return handler(request);
      fail('예상 밖 요청: ${request.url}');
    }));
  }

  test('refresh 가 401 이면 (토큰 무효 확정) 세션을 정리한다', () async {
    mockRefreshEndpoint((_) => http.Response('invalid token', 401));

    await auth.authorizedRequest(expiredThenOk);

    expect(await auth.jwt, isNull, reason: '무효 확정이면 토큰을 지운다');
    expect(await auth.refreshToken, isNull);
  });

  test('refresh 가 5xx 면 로그아웃하지 않고 이번 요청만 실패한다', () async {
    mockRefreshEndpoint((_) => http.Response('pool exhausted', 503));

    final response = await auth.authorizedRequest(expiredThenOk);

    expect(response.statusCode, 401, reason: '만료 응답을 그대로 반환한다');
    expect(await auth.jwt, 'old-jwt', reason: '토큰은 지우면 안 된다');
    expect(await auth.refreshToken, 'refresh-1');
    expect(sentTokens, ['old-jwt'], reason: '재시도 없이 1회만 보낸다');
  });

  test('refresh 가 429 면 로그아웃하지 않는다', () async {
    mockRefreshEndpoint((_) => http.Response('too many requests', 429));

    await auth.authorizedRequest(expiredThenOk);

    expect(await auth.jwt, 'old-jwt');
    expect(await auth.refreshToken, 'refresh-1');
  });

  test('refresh 가 타임아웃이면 로그아웃하지 않는다', () async {
    mockRefreshEndpoint(
      (_) => throw TimeoutException('refresh', const Duration(seconds: 15)),
    );

    final response = await auth.authorizedRequest(expiredThenOk);

    expect(response.statusCode, 401);
    expect(await auth.jwt, 'old-jwt');
    expect(await auth.refreshToken, 'refresh-1');
  });

  test('refresh 가 네트워크 예외면 로그아웃하지 않는다', () async {
    mockRefreshEndpoint(
      (_) => throw http.ClientException('Connection failed'),
    );

    final response = await auth.authorizedRequest(expiredThenOk);

    expect(response.statusCode, 401);
    expect(await auth.jwt, 'old-jwt');
    expect(await auth.refreshToken, 'refresh-1');
  });

  test('refresh 성공 시 새 토큰을 저장하고 원 요청을 재시도한다', () async {
    mockRefreshEndpoint(
      (_) => http.Response(
        jsonEncode({'accessToken': 'new-jwt', 'refreshToken': 'refresh-2'}),
        200,
      ),
    );

    final response = await auth.authorizedRequest(expiredThenOk);

    expect(response.statusCode, 200);
    expect(sentTokens, ['old-jwt', 'new-jwt'], reason: '새 토큰으로 재시도한다');
    expect(await auth.jwt, 'new-jwt');
    expect(await auth.refreshToken, 'refresh-2');
  });

  test('refresh 가 2xx 인데 accessToken 이 없으면 로그아웃하지 않는다', () async {
    mockRefreshEndpoint((_) => http.Response(jsonEncode({}), 200));

    final response = await auth.authorizedRequest(expiredThenOk);

    expect(response.statusCode, 401);
    expect(await auth.jwt, 'old-jwt', reason: '서버 응답 이상은 무효 확정이 아니다');
  });

  test('refreshToken 자체가 없으면 재발급 불가 — 세션을 정리한다', () async {
    FlutterSecureStorage.setMockInitialValues({jwtKey: 'old-jwt'});
    // refresh 호출 자체가 없어야 하므로 어떤 요청도 fail 처리.
    api.setApiClientForTesting(
      MockClient((request) async => fail('예상 밖 요청: ${request.url}')),
    );

    await auth.authorizedRequest(expiredThenOk);

    expect(await auth.jwt, isNull);
  });
}
