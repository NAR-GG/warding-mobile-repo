import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_remote_post.dart';

void main() {
  group('CommunityRemotePost.fromJson', () {
    test('목록 요약 필드를 그대로 매핑한다', () {
      final post = CommunityRemotePost.fromJson(const {
        'id': 42,
        'boardTeamId': null,
        'title': '오늘 밴픽 얘기',
        'bodyPreview': '본문 앞부분',
        'author': {'memberId': 7, 'nickname': '이름#0001'},
        'viewCount': 10,
        'likeCount': 3,
        'commentCount': 5,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
        'thumbnailUrl': 'https://res.cloudinary.com/x.png',
        'imageCount': 2,
      });

      expect(post.id, 42);
      expect(post.boardTeamId, isNull);
      expect(post.author?.nickname, '이름#0001');
      expect(post.imageCount, 2);
      expect(post.createdAt, DateTime.parse('2026-08-26T21:00:00'));
    });

    test('author가 없으면 탈퇴한 사용자로 null', () {
      final post = CommunityRemotePost.fromJson(const {
        'id': 1,
        'title': '',
        'bodyPreview': '',
        'author': null,
        'viewCount': 0,
        'likeCount': 0,
        'commentCount': 0,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
      });

      expect(post.author, isNull);
    });
  });

  group('CommunityRemotePostDetail.fromJson', () {
    test('본문·이미지·viewer를 포함해 매핑한다', () {
      final detail = CommunityRemotePostDetail.fromJson(const {
        'id': 42,
        'title': '제목',
        'bodyPreview': '',
        'author': {'memberId': 7, 'nickname': '이름#0001'},
        'viewCount': 10,
        'likeCount': 3,
        'commentCount': 5,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
        'body': '전문',
        'images': [
          {'id': 3, 'url': 'https://res.cloudinary.com/a.png'},
        ],
        'viewer': {
          'liked': true,
          'scrapped': false,
          'mine': false,
          'blockedAuthor': false,
        },
      });

      expect(detail.body, '전문');
      expect(detail.images, hasLength(1));
      expect(detail.images.first.id, 3);
      expect(detail.viewer.liked, isTrue);
      expect(detail.title, '제목');
      expect(detail.author?.memberId, 7);
    });

    test('blockedAuthor가 true면 title·body·images가 비어도 그대로 담는다', () {
      final detail = CommunityRemotePostDetail.fromJson(const {
        'id': 42,
        'title': '',
        'bodyPreview': '',
        'author': null,
        'viewCount': 0,
        'likeCount': 0,
        'commentCount': 0,
        'edited': false,
        'createdAt': '2026-08-26T21:00:00',
        'body': '',
        'images': [],
        'viewer': {
          'liked': false,
          'scrapped': false,
          'mine': false,
          'blockedAuthor': true,
        },
      });

      expect(detail.viewer.blockedAuthor, isTrue);
      expect(detail.title, '');
      expect(detail.images, isEmpty);
    });
  });

  group('CommunityRemotePostPage.fromJson', () {
    test('boardViewer가 없으면 null', () {
      final page = CommunityRemotePostPage.fromJson(const {
        'posts': [],
        'nextCursor': null,
      });

      expect(page.boardViewer, isNull);
      expect(page.nextCursor, isNull);
    });

    test('COOLDOWN 잠금 바를 파싱한다', () {
      final page = CommunityRemotePostPage.fromJson(const {
        'posts': [],
        'nextCursor': 42,
        'boardViewer': {
          'canWrite': false,
          'reason': 'COOLDOWN',
          'writableFrom': '2026-09-20T21:00:00',
        },
      });

      expect(page.nextCursor, 42);
      expect(page.boardViewer?.canWrite, isFalse);
      expect(page.boardViewer?.reason, CommunityWriteLockReason.cooldown);
      expect(
        page.boardViewer?.writableFrom,
        DateTime.parse('2026-09-20T21:00:00'),
      );
    });

    test('NOT_FAN 잠금 바를 파싱한다', () {
      final page = CommunityRemotePostPage.fromJson(const {
        'posts': [],
        'boardViewer': {'canWrite': false, 'reason': 'NOT_FAN'},
      });

      expect(page.boardViewer?.reason, CommunityWriteLockReason.notFan);
    });
  });
}
