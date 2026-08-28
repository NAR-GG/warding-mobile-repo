import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_my_activity.dart';

Map<String, dynamic> _postJson({int id = 1}) => {
  'id': id,
  'title': '제목',
  'bodyPreview': '',
  'author': null,
  'viewCount': 0,
  'likeCount': 0,
  'commentCount': 0,
  'edited': false,
  'createdAt': '2026-08-26T21:00:00',
};

void main() {
  test('CommunityScrapPage는 scrapId 커서로 항목을 담는다', () {
    final page = CommunityScrapPage.fromJson({
      'items': [
        {'scrapId': 12, 'post': _postJson(id: 42)},
      ],
      'nextCursor': 12,
    });

    expect(page.items.first.scrapId, 12);
    expect(page.items.first.post.id, 42);
    expect(page.nextCursor, 12);
  });

  test('CommunityLikePage는 likeId 커서로 항목을 담는다', () {
    final page = CommunityLikePage.fromJson({
      'items': [
        {'likeId': 7, 'post': _postJson(id: 1)},
      ],
      'nextCursor': 7,
    });

    expect(page.items.first.likeId, 7);
    expect(page.nextCursor, 7);
  });

  test('CommunityMyComment는 postId·postTitle을 담는다', () {
    final page = CommunityMyCommentPage.fromJson(const {
      'comments': [
        {
          'id': 9,
          'postId': 3,
          'postTitle': '원글 제목',
          'body': '내가 쓴 댓글',
          'likeCount': 1,
          'createdAt': '2026-08-26T21:00:00',
        },
      ],
      'nextCursor': 9,
    });

    expect(page.comments.first.postId, 3);
    expect(page.comments.first.postTitle, '원글 제목');
    expect(page.nextCursor, 9);
  });
}
