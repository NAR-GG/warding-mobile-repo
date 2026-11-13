import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/core/error/failure.dart';
import 'package:warding/features/shorts/data/repositories/shorts_repository_impl.dart';
import 'package:warding/core/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = ShortsRepositoryImpl();
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

    final result = await repo.fetchShortsPage(sort: 'views');

    expect(captured?.path, endsWith('/api/story/videos'));
    expect(captured?.queryParameters['category'], 'shorts');
    expect(captured?.queryParameters['sort'], 'views');
    final page = result.getOrElse((f) => fail('성공이어야 한다: \$f'));
    expect(page.items.single.title, '영상 1');
  });

  test('non-2xx 면 ServerFailure 를 돌려준다 (예외를 던지지 않는다)', () async {
    api.setApiClientForTesting(MockClient((_) async => http.Response('', 500)));

    final result = await repo.fetchShortsPage();

    // 던지지 않고 Left 로 돌려주므로 호출부가 실패 처리를 빠뜨릴 수 없다.
    final failure = result.getLeft().toNullable();
    expect(failure, isA<ServerFailure>());
    expect((failure! as ServerFailure).statusCode, 500);
  });
}
