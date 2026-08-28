import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/model/community_remote_comment.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/community/community_api_exception.dart';
import 'package:warding/repository/community/community_repository.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = CommunityRepository.instance;

  void loginAs(String jwt) {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': jwt,
      'refreshToken': 'test-refresh',
    });
    AuthService.instance.resetJwtCacheForTesting();
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance.resetJwtCacheForTesting();
  });

  tearDown(() => api.setApiClientForTesting(null));

  group('fetchPosts', () {
    test('토큰이 없으면 인증 헤더 없이 GET한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/mobile/community/posts');
          expect(request.headers['Authorization'], isNull);
          return http.Response('{"posts":[],"nextCursor":null}', 200);
        }),
      );

      final page = await repo.fetchPosts();

      expect(page.posts, isEmpty);
    });

    test('토큰이 있으면 Authorization 헤더와 boardTeamId 쿼리를 싣는다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-jwt');
          expect(request.url.query, contains('boardTeamId=39'));
          return http.Response('{"posts":[],"nextCursor":null}', 200);
        }),
      );

      await repo.fetchPosts(boardTeamId: 39);
    });

    test('실패 응답은 CommunityApiException을 던진다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              '{"code":"COMMUNITY_BOARD_FORBIDDEN","message":"권한이 없습니다."}',
            ),
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await expectLater(
        () => repo.fetchPosts(),
        throwsA(
          isA<CommunityApiException>().having(
            (e) => e.code,
            'code',
            'COMMUNITY_BOARD_FORBIDDEN',
          ),
        ),
      );
    });
  });

  test('fetchPostDetail은 상세를 파싱한다', () async {
    api.setApiClientForTesting(
      MockClient((request) async {
        expect(request.url.path, '/api/mobile/community/posts/42');
        return http.Response.bytes(
          utf8.encode(
            '{"id":42,"title":"제목","bodyPreview":"","author":null,'
            '"viewCount":0,"likeCount":0,"commentCount":0,"edited":false,'
            '"createdAt":"2026-08-26T21:00:00","body":"전문","images":[],'
            '"viewer":{"liked":false,"scrapped":false,"mine":false,"blockedAuthor":false}}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final detail = await repo.fetchPostDetail(42);

    expect(detail.id, 42);
    expect(detail.body, '전문');
  });

  group('createPost', () {
    test('작성 후 새 글 id를 반환한다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/community/posts');
          expect(request.body, contains('"title":"제목"'));
          return http.Response('{"id":43}', 200);
        }),
      );

      final id = await repo.createPost(title: '제목', body: '본문');

      expect(id, 43);
    });

    test('쿨다운 위반은 code와 retryAfterSeconds를 담아 던진다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              '{"code":"COMMUNITY_TEAM_COOLDOWN",'
              '"message":"응원팀을 바꾼 지 얼마 되지 않았습니다."}',
            ),
            403,
            headers: {
              'retry-after': '2592000',
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      await expectLater(
        () => repo.createPost(boardTeamId: 39, title: '제목', body: '본문'),
        throwsA(
          isA<CommunityApiException>()
              .having((e) => e.code, 'code', 'COMMUNITY_TEAM_COOLDOWN')
              .having(
                (e) => e.retryAfterSeconds,
                'retryAfterSeconds',
                2592000,
              ),
        ),
      );
    });
  });

  group('updatePost / deletePost / markPostViewed', () {
    setUp(() => loginAs('test-jwt'));

    test('imageUrls를 생략(null)하면 본문에 null로 실린다 — 이미지 변경 없음', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/mobile/community/posts/42');
          expect(request.body, contains('"imageUrls":null'));
          return http.Response('', 200);
        }),
      );

      await repo.updatePost(42, title: '수정', body: '수정 본문');
    });

    test('imageUrls에 빈 배열을 주면 전부 제거 요청이 실린다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.body, contains('"imageUrls":[]'));
          return http.Response('', 200);
        }),
      );

      await repo.updatePost(
        42,
        title: '수정',
        body: '수정 본문',
        imageUrls: const [],
      );
    });

    test('deletePost는 DELETE로 호출한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/mobile/community/posts/42');
          return http.Response('', 204);
        }),
      );

      await repo.deletePost(42);
    });

    test('markPostViewed는 인증 없이 POST한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/community/posts/42/view');
          expect(request.headers['Authorization'], isNull);
          return http.Response('', 204);
        }),
      );

      await repo.markPostViewed(42);
    });
  });

  group('toggleLike / toggleScrap', () {
    setUp(() => loginAs('test-jwt'));

    test('toggleLike는 서버 응답의 liked·likeCount를 그대로 반환한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/posts/42/like');
          return http.Response('{"liked":true,"likeCount":4}', 200);
        }),
      );

      final result = await repo.toggleLike(42);

      expect(result.liked, isTrue);
      expect(result.likeCount, 4);
    });

    test('toggleScrap은 scrapped를 반환한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/posts/42/scrap');
          return http.Response('{"scrapped":true}', 200);
        }),
      );

      final scrapped = await repo.toggleScrap(42);

      expect(scrapped, isTrue);
    });
  });

  group('comments', () {
    test('fetchComments는 오래된 순 페이지를 파싱한다', () async {
      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/posts/42/comments');
          return http.Response.bytes(
            utf8.encode(
              '{"comments":[{"id":9,"parentId":5,"body":"답글","status":"VISIBLE",'
              '"author":{"memberId":1,"nickname":"a"},"likeCount":1,"liked":false,'
              '"mine":false,"createdAt":"2026-08-26T21:00:00"}],"nextCursor":9}',
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final page = await repo.fetchComments(42);

      expect(page.comments, hasLength(1));
      expect(page.comments.first.status, CommunityCommentStatus.visible);
    });

    test('createComment는 replyToCommentId를 대상 댓글 id 그대로 보낸다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/community/posts/42/comments');
          expect(request.body, contains('"replyToCommentId":5'));
          return http.Response('{"id":10}', 200);
        }),
      );

      final id = await repo.createComment(
        42,
        body: '답글',
        replyToCommentId: 5,
      );

      expect(id, 10);
    });

    test('최상위 댓글이면 replyToCommentId를 보내지 않는다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.body, isNot(contains('replyToCommentId')));
          return http.Response('{"id":11}', 200);
        }),
      );

      await repo.createComment(42, body: '최상위 댓글');
    });

    test('deleteComment는 DELETE로 호출한다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/mobile/community/comments/9');
          return http.Response('', 204);
        }),
      );

      await repo.deleteComment(9);
    });

    test('toggleCommentLike는 liked·likeCount를 반환한다', () async {
      loginAs('test-jwt');

      api.setApiClientForTesting(
        MockClient((request) async {
          expect(request.url.path, '/api/mobile/community/comments/9/like');
          return http.Response('{"liked":true,"likeCount":2}', 200);
        }),
      );

      final result = await repo.toggleCommentLike(9);

      expect(result.liked, isTrue);
      expect(result.likeCount, 2);
    });
  });
}
