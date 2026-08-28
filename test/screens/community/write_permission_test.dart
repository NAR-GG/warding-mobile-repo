import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/model/community_remote_post.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/screens/community/community_permission.dart';
import 'package:warding/util/api_client.dart' as api;
import 'package:warding/viewmodel/community/community_list_viewmodel.dart';

/// 커뮤니티의 비자명한 로직은 "여기에 글을 쓸 수 있는가" 하나다. 목록·상세
/// 렌더는 응답을 그대로 그리는 것뿐이라 테스트하지 않는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('canWriteToBoard', () {
    test('회원은 전체 게시판에 쓸 수 있다', () {
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: 39, boardTeamId: null),
        isTrue,
      );
    });

    test('회원은 자기 응원팀 게시판에 쓸 수 있다', () {
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: 39, boardTeamId: 39),
        isTrue,
      );
    });

    test('회원도 다른 팀 게시판에는 못 쓴다', () {
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: 39, boardTeamId: 23),
        isFalse,
      );
    });

    test('응원팀 미설정 회원은 전체만 쓰고 팀 게시판은 못 쓴다', () {
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: null, boardTeamId: null),
        isTrue,
      );
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: null, boardTeamId: 39),
        isFalse,
      );
    });

    test('비회원은 전체 게시판도 못 쓴다', () {
      expect(
        canWriteToBoard(loggedIn: false, myTeamId: 39, boardTeamId: null),
        isFalse,
      );
      expect(
        canWriteToBoard(loggedIn: false, myTeamId: 39, boardTeamId: 39),
        isFalse,
      );
    });
  });

  group('CommunityListViewModel', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      AuthService.instance.resetJwtCacheForTesting();
    });

    tearDown(() => api.setApiClientForTesting(null));

    void loginAs({int? favoriteTeamId}) {
      FlutterSecureStorage.setMockInitialValues({
        'jwt': 'test-jwt',
        'refreshToken': 'test-refresh',
      });
      AuthService.instance.resetJwtCacheForTesting();
    }

    /// `/auth/me` 와 커뮤니티 목록만 답하는 서버.
    void serve({
      int? favoriteTeamId,
      Map<String, dynamic>? boardViewer,
      List<Map<String, dynamic>> posts = const [],
      int? nextCursor,
      void Function(http.Request request)? onPosts,
    }) {
      api.setApiClientForTesting(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/me')) {
            return http.Response(
              jsonEncode({'id': 1, 'favoriteTeamId': favoriteTeamId}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          onPosts?.call(request);
          return http.Response(
            jsonEncode({
              'posts': posts,
              'nextCursor': nextCursor,
              if (boardViewer != null) 'boardViewer': boardViewer,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    }

    test('비회원은 어디에도 못 쓴다', () async {
      serve();
      final vm = CommunityListViewModel();
      await vm.init();

      expect(vm.loggedIn, isFalse);
      expect(vm.canWrite(null), isFalse);
      expect(vm.canWrite(39), isFalse);
      vm.dispose();
    });

    test('서버 판정이 오면 응원팀이어도 그쪽을 따른다 (쿨다운)', () async {
      loginAs();
      serve(
        favoriteTeamId: 39,
        boardViewer: {
          'canWrite': false,
          'reason': 'COOLDOWN',
          'writableFrom': '2026-09-20T00:00:00Z',
        },
      );
      final vm = CommunityListViewModel();
      await vm.init();
      await vm.load(39);

      // 로컬 규칙만 보면 내 응원팀이라 쓸 수 있어야 하지만, 응원팀을 바꾼 지
      // 30일이 안 지난 건 앱이 알 수 없다. 서버 판정이 이긴다.
      expect(
        canWriteToBoard(loggedIn: true, myTeamId: 39, boardTeamId: 39),
        isTrue,
      );
      expect(vm.canWrite(39), isFalse);
      expect(vm.lockReason(39), CommunityWriteLockReason.cooldown);
      expect(vm.writableFrom(39), isNotNull);
      vm.dispose();
    });

    test('이미 받아온 게시판은 다시 받지 않고, refresh 면 받는다', () async {
      var calls = 0;
      serve(onPosts: (_) => calls++);
      final vm = CommunityListViewModel();
      await vm.init(); // 전체 게시판 1회
      await vm.load(null); // 캐시 — 요청 없음
      expect(calls, 1);

      await vm.load(null, refresh: true);
      expect(calls, 2);
      vm.dispose();
    });

    test('다음 커서가 없으면 더 불러오지 않는다', () async {
      var calls = 0;
      serve(
        posts: [
          {'id': 1, 'title': 'a', 'bodyPreview': 'b'},
        ],
        onPosts: (_) => calls++,
      );
      final vm = CommunityListViewModel();
      await vm.init();
      expect(vm.board(null).posts, hasLength(1));
      expect(vm.board(null).hasMore, isFalse);

      await vm.loadMore(null);
      expect(calls, 1);
      vm.dispose();
    });
  });
}
