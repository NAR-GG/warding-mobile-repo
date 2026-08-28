import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_remote_comment.dart';

void main() {
  group('CommunityRemoteComment.fromJson', () {
    test('VISIBLE 댓글은 body·author를 그대로 담는다', () {
      final comment = CommunityRemoteComment.fromJson(const {
        'id': 9,
        'parentId': 5,
        'body': '이거 진짜 체감됐음',
        'status': 'VISIBLE',
        'author': {'memberId': 1, 'nickname': '황금독수리'},
        'mentionNickname': '번역봇#0002',
        'likeCount': 1,
        'liked': false,
        'mine': false,
        'createdAt': '2026-08-26T21:00:00',
      });

      expect(comment.status, CommunityCommentStatus.visible);
      expect(comment.body, '이거 진짜 체감됐음');
      expect(comment.author?.nickname, '황금독수리');
      expect(comment.mentionNickname, '번역봇#0002');
      expect(comment.parentId, 5);
    });

    test('최상위 댓글은 parentId가 null', () {
      final comment = CommunityRemoteComment.fromJson(const {
        'id': 1,
        'parentId': null,
        'body': '본문',
        'status': 'VISIBLE',
        'author': {'memberId': 1, 'nickname': 'a'},
        'likeCount': 0,
        'liked': false,
        'mine': false,
        'createdAt': '2026-08-26T21:00:00',
      });

      expect(comment.parentId, isNull);
    });

    for (final status in ['DELETED', 'BLOCKED', 'HIDDEN']) {
      test('$status 댓글은 body·author가 null이어도 행이 유지된다', () {
        final comment = CommunityRemoteComment.fromJson({
          'id': 4,
          'parentId': null,
          'body': null,
          'status': status,
          'author': null,
          'likeCount': 0,
          'liked': false,
          'mine': false,
          'createdAt': '2026-08-26T21:00:00',
        });

        expect(comment.id, 4);
        expect(comment.body, isNull);
        expect(comment.author, isNull);
      });
    }
  });

  group('CommunityRemoteCommentPage.fromJson', () {
    test('오래된 순 커서 페이지를 파싱한다', () {
      final page = CommunityRemoteCommentPage.fromJson(const {
        'comments': [
          {
            'id': 9,
            'parentId': null,
            'body': '본문',
            'status': 'VISIBLE',
            'author': {'memberId': 1, 'nickname': 'a'},
            'likeCount': 0,
            'liked': false,
            'mine': false,
            'createdAt': '2026-08-26T21:00:00',
          },
        ],
        'nextCursor': 9,
      });

      expect(page.comments, hasLength(1));
      expect(page.nextCursor, 9);
    });
  });
}
