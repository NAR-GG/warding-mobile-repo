import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/my_community_activity/my_community_activity_viewmodel.dart';

/// 본문에 한글이 섞여 있어 UTF-8 로 명시해야 한다 — `http.Response(String, ...)`
/// 는 charset 헤더가 없으면 latin1 로 해석해 'Invalid argument' 로 죽는다.
http.Response _jsonResponse(String body, {int status = 200}) =>
    http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  String postJson({required int id, int? boardTeamId, String? boardTeamCode}) =>
      '{"id":$id,"boardTeamId":${boardTeamId ?? 'null'},'
      '"boardTeamCode":${boardTeamCode == null ? 'null' : '"$boardTeamCode"'},'
      '"title":"제목$id","bodyPreview":"","author":null,"viewCount":0,'
      '"likeCount":0,"commentCount":0,"edited":false,'
      '"createdAt":"2026-08-26T21:00:00"}';

  test('loadPosts는 첫 페이지를 읽고 loaded 를 켠다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/posts');
        return _jsonResponse('{"posts":[${postJson(id: 1)}],"nextCursor":1}');
      }),
    );

    final vm = MyCommunityActivityViewModel();
    await vm.loadPosts();

    expect(vm.posts.loaded, isTrue);
    expect(vm.posts.items, hasLength(1));
    expect(vm.posts.items.first.id, 1);
    expect(vm.posts.hasMore, isTrue);
  });

  test('loadPosts를 다시 부르면(같은 버전) 재요청하지 않는다 — refresh 일 때만 다시 받는다', () async {
    var callCount = 0;
    api.setApiClientForTesting(
      MockClient((request) async {
        callCount++;
        return _jsonResponse(
          '{"posts":[${postJson(id: 1)}],"nextCursor":null}',
        );
      }),
    );

    final vm = MyCommunityActivityViewModel();
    await vm.loadPosts();
    await vm.loadPosts();
    expect(callCount, 1);

    await vm.loadPosts(refresh: true);
    expect(callCount, 2);
  });

  test('loadMorePosts는 커서로 다음 페이지를 요청해 이어 붙인다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        final cursor = request.url.queryParameters['cursor'];
        if (cursor == null) {
          return _jsonResponse('{"posts":[${postJson(id: 1)}],"nextCursor":1}');
        }
        expect(cursor, '1');
        return _jsonResponse(
          '{"posts":[${postJson(id: 2)}],"nextCursor":null}',
        );
      }),
    );

    final vm = MyCommunityActivityViewModel();
    await vm.loadPosts();
    await vm.loadMorePosts();

    expect(vm.posts.items.map((p) => p.id), [1, 2]);
    expect(vm.posts.hasMore, isFalse);
  });

  test('loadMorePosts는 hasMore 가 false 면 요청하지 않는다', () async {
    var callCount = 0;
    api.setApiClientForTesting(
      MockClient((request) async {
        callCount++;
        return _jsonResponse(
          '{"posts":[${postJson(id: 1)}],"nextCursor":null}',
        );
      }),
    );

    final vm = MyCommunityActivityViewModel();
    await vm.loadPosts();
    await vm.loadMorePosts();

    expect(callCount, 1);
  });

  test('탭 세 개(글·댓글·스크랩)의 로딩 상태는 서로 섞이지 않는다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        if (request.url.path.endsWith('/posts')) {
          return _jsonResponse(
            '{"posts":[${postJson(id: 1)}],"nextCursor":null}',
          );
        }
        if (request.url.path.endsWith('/comments')) {
          return _jsonResponse(
            '{"comments":[{"id":10,"postId":1,"postTitle":"글1",'
            '"body":"댓글","likeCount":0,"createdAt":"2026-08-26T21:00:00",'
            '"boardTeamId":null,"boardTeamCode":null}],"nextCursor":null}',
          );
        }
        return _jsonResponse('{"items":[],"nextCursor":null}');
      }),
    );

    final vm = MyCommunityActivityViewModel();
    await vm.loadPosts();
    await vm.loadComments();
    await vm.loadScraps();

    expect(vm.posts.items, hasLength(1));
    expect(vm.comments.items, hasLength(1));
    expect(vm.scraps.items, isEmpty);
    expect(vm.posts.loaded, isTrue);
    expect(vm.comments.loaded, isTrue);
    expect(vm.scraps.loaded, isTrue);
  });

  test('실패 응답이면 error 를 채우고 목록은 비운다', () async {
    api.setApiClientForTesting(
      MockClient((request) async => _jsonResponse('{}', status: 500)),
    );

    final vm = MyCommunityActivityViewModel();
    await vm.loadPosts();

    expect(vm.posts.error, isNotNull);
    expect(vm.posts.items, isEmpty);
    expect(vm.posts.loaded, isFalse);
  });

  test('boardTeamCode 를 그대로 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient(
        (request) async => _jsonResponse(
          '{"posts":[${postJson(id: 1, boardTeamId: 3, boardTeamCode: 'GEN')}],'
          '"nextCursor":null}',
        ),
      ),
    );

    final vm = MyCommunityActivityViewModel();
    await vm.loadPosts();

    expect(vm.posts.items.first.boardTeamCode, 'GEN');
  });
}
