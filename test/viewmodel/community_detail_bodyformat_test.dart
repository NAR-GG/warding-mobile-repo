import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/community/community_detail_viewmodel.dart';

/// v1.0.23 실사고 회귀: 좋아요·벨 토글이 상세 객체를 재조립하면서 bodyFormat 을
/// 빼먹어 PLAIN 으로 리셋 → 블록 글 본문이 원문 JSON 으로 표시됐다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const detailJson = {
    'id': 4,
    'title': '도란 나서스 ㅋㅋㅋ',
    'body':
        '[{"type":"embed","provider":"youtube","url":"https://youtube.com/shorts/x"},'
        '{"type":"text","text":"1400스택","style":"body"}]',
    'bodyFormat': 'BLOCKS',
    'likeCount': 0,
    'commentCount': 0,
    'viewer': {'liked': false, 'scrapped': false, 'mine': false},
  };

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
    api.setApiClientForTesting(
      MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/me')) {
          return http.Response(jsonEncode({'id': 1}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/posts/4')) {
          return http.Response(jsonEncode(detailJson), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/comments')) {
          return http.Response(jsonEncode({'comments': [], 'nextCursor': null}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/like')) {
          return http.Response(jsonEncode({'liked': true, 'likeCount': 1}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/notification')) {
          return http.Response(jsonEncode({'enabled': false}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/view')) {
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      }),
    );
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('좋아요·벨 토글 후에도 bodyFormat(BLOCKS)이 유지된다', () async {
    final vm = CommunityDetailViewModel(postId: 4);
    await vm.load();
    expect(vm.post!.isBlocks, isTrue);

    await vm.toggleLike();
    expect(vm.post!.isBlocks, isTrue,
        reason: '좋아요 토글이 bodyFormat 을 PLAIN 으로 리셋하면 안 된다');
    expect(vm.post!.likeCount, 1);

    await vm.toggleNotification();
    expect(vm.post!.isBlocks, isTrue,
        reason: '벨 토글이 bodyFormat 을 PLAIN 으로 리셋하면 안 된다');

    vm.dispose();
  });
}
