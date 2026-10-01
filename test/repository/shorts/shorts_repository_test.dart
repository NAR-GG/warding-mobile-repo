import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/shorts/shorts_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ShortsRepository.instance;
  tearDown(() => api.setApiClientForTesting(null));

  test('category=shorts, sort를 쿼리로 보내고 content를 파싱한다', () async {
    Uri? captured;
    api.setApiClientForTesting(MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'content': [
            {'videoId': 1, 'youtubeVideoId': 'a', 'title': '영상 1', 'viewCount': 100},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final videos = await repo.fetchShorts(sort: 'views');

    expect(captured?.path, endsWith('/api/story/videos'));
    expect(captured?.queryParameters['category'], 'shorts');
    expect(captured?.queryParameters['sort'], 'views');
    expect(videos.single.title, '영상 1');
  });

  test('non-2xx면 예외', () async {
    api.setApiClientForTesting(MockClient((_) async => http.Response('', 500)));
    await expectLater(repo.fetchShorts(), throwsA(isA<Exception>()));
  });
}
