import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_activity_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityActivityRepository.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'test-jwt',
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  test('fetchScraps는 scrapId 커서 페이지를 파싱하고 Authorization을 싣는다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/scraps');
        expect(request.headers['Authorization'], 'Bearer test-jwt');
        return http.Response.bytes(
          utf8.encode(
            '{"items":[{"scrapId":12,"post":{"id":42,"title":"제목",'
            '"bodyPreview":"","author":null,"viewCount":0,"likeCount":0,'
            '"commentCount":0,"edited":false,"createdAt":"2026-08-26T21:00:00"}}],'
            '"nextCursor":12}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final page = await repo.fetchScraps();

    expect(page.items, hasLength(1));
    expect(page.items.first.scrapId, 12);
    expect(page.items.first.post.id, 42);
  });

  test('fetchMyPosts는 게시글 페이지 형태로 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/posts');
        return http.Response('{"posts":[],"nextCursor":null}', 200);
      }),
    );

    final page = await repo.fetchMyPosts();

    expect(page.posts, isEmpty);
  });

  test('fetchMyLikes는 likeId 커서 페이지를 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/likes');
        return http.Response(
          '{"items":[{"likeId":7,"post":{"id":1,"title":"","bodyPreview":"",'
          '"author":null,"viewCount":0,"likeCount":0,"commentCount":0,'
          '"edited":false,"createdAt":"2026-08-26T21:00:00"}}],"nextCursor":7}',
          200,
        );
      }),
    );

    final page = await repo.fetchMyLikes();

    expect(page.items.first.likeId, 7);
  });

  test('fetchMyComments는 postId·postTitle을 포함해 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/me/community/comments');
        return http.Response.bytes(
          utf8.encode(
            '{"comments":[{"id":9,"postId":3,"postTitle":"원글 제목","body":"...",'
            '"likeCount":1,"createdAt":"2026-08-26T21:00:00"}],"nextCursor":9}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final page = await repo.fetchMyComments();

    expect(page.comments.first.postId, 3);
    expect(page.comments.first.postTitle, '원글 제목');
  });
}
