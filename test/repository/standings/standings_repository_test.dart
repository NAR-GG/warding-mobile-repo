import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/standings/standings_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = StandingsRepository.instance;
  tearDown(() => api.setApiClientForTesting(null));

  test('league 쿼리파라미터로 조회하고 응답을 파싱한다', () async {
    Uri? captured;
    api.setApiClientForTesting(MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'league': 'LCK',
          'supported': true,
          'scopeLabel': '정규시즌',
          'groups': [
            {
              'name': '레전드 그룹',
              'rows': [
                {'rank': 1, 'teamCode': 'GEN', 'teamName': 'Gen.G', 'wins': 19, 'losses': 7, 'setDiff': 22},
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final result = await repo.fetchStandings('LCK');

    expect(captured?.queryParameters['league'], 'LCK');
    expect(result.groups.single.rows.single.teamCode, 'GEN');
  });

  test('non-2xx면 예외를 던진다', () async {
    api.setApiClientForTesting(MockClient((_) async => http.Response('', 500)));
    await expectLater(repo.fetchStandings('LCK'), throwsA(isA<Exception>()));
  });
}
