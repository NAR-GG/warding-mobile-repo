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
    // AuthService.instance 는 이 파일의 모든 테스트가 공유하는 싱글턴이라,
    // jwt 인메모리 캐시가 이전 테스트 값으로 남지 않도록 매번 지운다.
    auth.resetJwtCacheForTesting();
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

  group('jwt 인메모리 캐시', () {
    // 기기 잠금 중 Keychain 접근성 불일치 등으로 실제로는 로그인 상태인데도
    // 한 번의 조회가 예외 없이 null 을 반환하는 경우가 있었다(과거 -25308
    // 오탐 로그아웃 사고, splash_screen.dart 참고). 이 null 을 캐싱해버리면
    // 그 순간의 헛읽기가 앱 재시작 전까지 영구히 '로그아웃'으로 굳는다.
    test('null 읽기는 캐싱하지 않는다 — 다음 읽기에서 storage 를 다시 본다', () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await auth.jwt, isNull);

      // storage 에 토큰이 다시 나타나도(예: 잠금 해제 후 정상 조회) 캐시가
      // null 로 굳어 있지 않아야 이 값을 곧바로 돌려줄 수 있다.
      FlutterSecureStorage.setMockInitialValues({jwtKey: 'recovered-jwt'});
      expect(await auth.jwt, 'recovered-jwt');
    });

    test('non-null 읽기는 캐싱해 이후 읽기가 storage 를 다시 보지 않는다', () async {
      expect(await auth.jwt, 'old-jwt');

      // storage 값이 바뀌어도 캐시된 값을 그대로 돌려준다(로그아웃 등 실제
      // 변경은 항상 _setCachedJwt 를 거치므로 이 경로로는 안 바뀐다).
      FlutterSecureStorage.setMockInitialValues({jwtKey: 'other-jwt'});
      expect(await auth.jwt, 'old-jwt');
    });
  });

  group('만료 판별', () {
    // 게이트웨이(nginx·ALB)는 502·503·504 에러 페이지를 text/html 로 내려준다.
    // content-type 만 보고 만료로 판단하면 서버가 아플 때의 5xx 를 '인증 만료'로
    // 오판해 불필요한 재발급·토큰 로테이션이 돈다.
    test('5xx + text/html 은 만료가 아니다 — 재발급을 시도하지 않는다', () async {
      // _doRefresh 는 예외를 잡아 transient 로 접으므로, 여기서 fail() 을
      // 던지면 삼켜져 테스트가 통과해버린다. 호출 횟수를 세서 밖에서 검증한다.
      var refreshCalls = 0;
      api.setApiClientForTesting(
        MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls++;
            return http.Response(
              jsonEncode({'accessToken': 'should-not-be-used'}),
              200,
            );
          }
          return http.Response('예상 밖 요청', 500);
        }),
      );

      var sendCalls = 0;
      final response = await auth.authorizedRequest((token) async {
        sendCalls++;
        return http.Response(
          '<html><body>502 Bad Gateway</body></html>',
          502,
          headers: {'content-type': 'text/html'},
        );
      });

      expect(refreshCalls, 0, reason: '5xx HTML 을 만료로 오판해 재발급하면 안 된다');
      expect(sendCalls, 1, reason: '재시도하지 않고 한 번만 보낸다');
      expect(response.statusCode, 502, reason: '응답을 그대로 호출부에 돌려준다');
      expect(await auth.jwt, 'old-jwt', reason: '토큰은 건드리지 않는다');
    });

    test('302 + text/html(로그인 페이지)은 만료로 보고 재발급한다', () async {
      mockRefreshEndpoint(
        (_) => http.Response(jsonEncode({'accessToken': 'new-jwt'}), 200),
      );

      var calls = 0;
      final response = await auth.authorizedRequest((token) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            '<html>login</html>',
            302,
            headers: {'content-type': 'text/html'},
          );
        }
        return http.Response('ok', 200);
      });

      expect(response.statusCode, 200);
      expect(await auth.jwt, 'new-jwt');
    });
  });
}
