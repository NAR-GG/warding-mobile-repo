import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/subscription/subscription_repository.dart';
import 'package:warding/util/api_client.dart' as api;

/// 2026-08-18 버그 회귀 테스트.
///
/// 1) `PUT .../player-subscriptions/{id}`, `PUT .../notification-subscriptions/{id}`
///    가 성공 시 204 No Content(빈 바디)를 주는데, 예전 코드는 무조건
///    `jsonDecode(response.body)` 를 해서 FormatException 으로 죽었다.
/// 2) [SubscriptionRepository.fetchSubscribedPlayers] 의 30초 캐시가
///    구독/해제/알림설정 변경 후에도 지워지지 않아, 토글 직후 재조회하면
///    토글 이전 값으로 되돌아가 보였다.
void main() {
  // AuthService 가 navigatorKey.currentState 를 참조하므로 바인딩이 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();

  final auth = AuthService.instance;
  final repo = SubscriptionRepository.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'valid-jwt',
      'refreshToken': 'refresh-1',
    });
    auth.resetJwtCacheForTesting();
    repo.resetCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  group('204 No Content 처리', () {
    test('updatePlayerAlarm(): 빈 바디 204 응답을 에러 없이 처리한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, contains('/player-subscriptions/42'));
          return http.Response('', 204);
        }),
      );

      await expectLater(
        repo.updatePlayerAlarm(42, startEnabled: true, endEnabled: false),
        completes,
      );
    });

    test('updateTeamNotification(): 빈 바디 204 응답을 에러 없이 처리한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, contains('/notification-subscriptions/7'));
          return http.Response('', 204);
        }),
      );

      await expectLater(
        repo.updateTeamNotification(
          7,
          setStartEnabled: true,
          setEndEnabled: true,
          liveEventEnabled: true,
          killEnabled: false,
          baronEnabled: true,
          dragonEnabled: true,
          towerEnabled: true,
          inhibitorEnabled: true,
        ),
        completes,
      );
    });
  });

  group('구독 선수 캐시', () {
    test('fetchSubscribedPlayers(): 30초 내 재호출은 네트워크를 타지 않는다', () async {
      var getCount = 0;
      api.setApiClientForTesting(
        MockClient((request) async {
          getCount++;
          return http.Response('[]', 200);
        }),
      );

      await repo.fetchSubscribedPlayers();
      await repo.fetchSubscribedPlayers();

      expect(getCount, 1, reason: '캐시가 있으면 두 번째 호출은 네트워크를 타면 안 된다');
    });

    test('updatePlayerAlarm(): 성공하면 캐시를 지워 다음 조회가 최신값을 받아온다', () async {
      var getCount = 0;
      api.setApiClientForTesting(
        MockClient((request) async {
          switch (request.method) {
            case 'GET':
              getCount++;
              return http.Response('[]', 200);
            case 'PUT':
              return http.Response('', 204);
            default:
              fail('예상 밖 요청: ${request.method} ${request.url}');
          }
        }),
      );

      await repo.fetchSubscribedPlayers(); // 1회차 — 캐시에 적재.
      await repo.updatePlayerAlarm(42, startEnabled: true, endEnabled: false);
      await repo.fetchSubscribedPlayers(); // 캐시가 지워졌으니 다시 네트워크를 타야 한다.

      expect(getCount, 2, reason: '알림 설정 변경 후에는 캐시가 무효화돼야 한다');
    });

    test('subscribePlayer(): 성공하면 캐시를 지운다', () async {
      var getCount = 0;
      api.setApiClientForTesting(
        MockClient((request) async {
          if (request.method == 'GET') {
            getCount++;
            return http.Response('[]', 200);
          }
          return http.Response(
            '{"playerId":1,"playerName":"Faker","playerImageUrl":"",'
            '"role":"MID","teamId":1,"teamCode":"T1","teamName":"T1",'
            '"teamImageUrl":"","subscribed":true,"startEnabled":true,'
            '"endEnabled":true}',
            200,
          );
        }),
      );

      await repo.fetchSubscribedPlayers();
      await repo.subscribePlayer(1);
      await repo.fetchSubscribedPlayers();

      expect(getCount, 2, reason: '구독 추가 후에는 캐시가 무효화돼야 한다');
    });

    test('unsubscribePlayer(): 성공하면 캐시를 지운다', () async {
      var getCount = 0;
      api.setApiClientForTesting(
        MockClient((request) async {
          if (request.method == 'GET') {
            getCount++;
            return http.Response('[]', 200);
          }
          return http.Response('', 204);
        }),
      );

      await repo.fetchSubscribedPlayers();
      await repo.unsubscribePlayer(1);
      await repo.fetchSubscribedPlayers();

      expect(getCount, 2, reason: '구독 해제 후에는 캐시가 무효화돼야 한다');
    });
  });
}
