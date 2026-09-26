import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/home/home_api_sources.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => api.setApiClientForTesting(null));

  final now = DateTime.parse('2026-09-25T21:30:00+09:00');

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('parseServerTime', () {
    test('오프셋이 없으면 KST 로 본다', () {
      expect(
        parseServerTime('2026-09-16T22:19:16.39'),
        DateTime.parse('2026-09-16T22:19:16.39+09:00'),
      );
    });

    test('오프셋이 있으면 그대로 쓴다', () {
      expect(
        parseServerTime('2026-09-25T21:03:12+09:00'),
        DateTime.parse('2026-09-25T21:03:12+09:00'),
      );
    });

    test('비었거나 깨졌으면 null', () {
      expect(parseServerTime(null), isNull);
      expect(parseServerTime(''), isNull);
      expect(parseServerTime('어제'), isNull);
    });
  });

  group('ApiSoloRankSource', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({'jwt': 'token'});
      AuthService.instance.resetJwtCacheForTesting();
    });

    test('live 는 startedAt 부터 경과 초를, finished 는 종료 후 분·경기 길이를 계산한다', () async {
      Uri? url;
      String? auth;
      api.setApiClientForTesting(MockClient((request) async {
        url = request.url;
        auth = request.headers['Authorization'];
        return json({
          'live': [
            {
              'playerId': 1,
              'playerName': 'Faker',
              'playerImageUrl': 'https://img/faker.png',
              'teamCode': 'T1',
              'championName': '아리',
              'startedAt': '2026-09-25T21:03:12+09:00',
            },
          ],
          'finished': [
            {
              'playerId': 2,
              'playerName': 'Oner',
              'teamCode': 'T1',
              'championName': '리 신',
              'win': true,
              'durationSeconds': 1920,
              'endedAt': '2026-09-25T20:48:00+09:00',
            },
          ],
        });
      }));

      final snap = await ApiSoloRankSource(now: () => now).fetch();

      expect(url!.path, '/api/mobile/me/solo-rank');
      expect(auth, 'Bearer token');
      final live = snap.live.single;
      expect(live.name, 'Faker');
      expect(live.teamCode, 'T1');
      expect(live.champion, '아리');
      expect(live.elapsedSeconds, 26 * 60 + 48);
      expect(live.playerImageUrl, 'https://img/faker.png');
      final done = snap.finished.single;
      expect(done.name, 'Oner');
      expect(done.won, isTrue);
      expect(done.minutesAgo, 42);
      expect(done.durationMinutes, 32);
    });

    test('승패를 못 받은 판(win: null)은 끝난 경기에서 뺀다', () async {
      api.setApiClientForTesting(MockClient((_) async => json({
        'live': [],
        'finished': [
          {
            'playerName': 'Oner',
            'teamCode': 'T1',
            'win': null,
            'endedAt': '2026-09-25T21:00:00+09:00',
          },
          {
            'playerName': 'Ruler',
            'teamCode': 'HLE',
            'win': false,
            'durationSeconds': 1500,
            'endedAt': '2026-09-25T21:00:00+09:00',
          },
        ],
      })));

      final snap = await ApiSoloRankSource(now: () => now).fetch();

      expect(snap.finished.map((p) => p.name), ['Ruler']);
      expect(snap.finished.single.won, isFalse);
    });

    test('토큰이 없으면(비회원) 요청 없이 빈 결과', () async {
      FlutterSecureStorage.setMockInitialValues({});
      AuthService.instance.resetJwtCacheForTesting();
      var called = false;
      api.setApiClientForTesting(MockClient((_) async {
        called = true;
        return json({});
      }));

      final snap = await ApiSoloRankSource(now: () => now).fetch();

      expect(called, isFalse);
      expect(snap.live, isEmpty);
      expect(snap.finished, isEmpty);
    });

    test('서버 오류면 예외', () async {
      api.setApiClientForTesting(
        MockClient((_) async => json({'message': 'fail'}, 500)),
      );

      expect(ApiSoloRankSource(now: () => now).fetch(), throwsException);
    });
  });

  group('ApiNewsSource', () {
    test('제목·언론사·경과 분·썸네일 유무를 매핑한다(KST 오프셋 없는 시각)', () async {
      Uri? url;
      api.setApiClientForTesting(MockClient((request) async {
        url = request.url;
        return json([
          {
            'id': 1,
            'title': 'T1, 플레이오프 진출 확정',
            'officeName': '포모스',
            'thumbnail': 'https://img/1.jpg',
            'postUrl': 'https://n.news.naver.com/1',
            'createdAt': '2026-09-25T20:50:00',
          },
          {
            'id': 2,
            'title': '썸네일 없는 기사',
            'officeName': '인벤',
            'thumbnail': null,
            'createdAt': '2026-09-25T18:30:00',
          },
        ]);
      }));

      final list = await ApiNewsSource(now: () => now).fetchTop();

      expect(url!.path, '/api/home/news');
      expect(list.map((a) => a.title), ['T1, 플레이오프 진출 확정', '썸네일 없는 기사']);
      expect(list.first.office, '포모스');
      expect(list.first.minutesAgo, 40);
      expect(list.first.hasThumbnail, isTrue);
      expect(list.last.minutesAgo, 180);
      expect(list.last.hasThumbnail, isFalse);
    });

    test('서버 오류면 예외', () async {
      api.setApiClientForTesting(
        MockClient((_) async => json({'message': 'fail'}, 500)),
      );

      expect(ApiNewsSource(now: () => now).fetchTop(), throwsException);
    });
  });
}
