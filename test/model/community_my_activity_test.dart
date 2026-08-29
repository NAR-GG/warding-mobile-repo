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
    // 게시판 키가 없는 응답(구버전 서버)은 전체 게시판과 같은 모양으로 떨어진다.
    expect(page.comments.first.boardTeamId, isNull);
    expect(page.comments.first.boardTeamCode, isNull);
  });

  test('CommunityMyComment는 원글이 속한 게시판을 담는다', () {
    final page = CommunityMyCommentPage.fromJson(const {
      'comments': [
        {
          'id': 9,
          'postId': 3,
          'postTitle': '팀 게시판 원글',
          'boardTeamId': 23,
          'boardTeamCode': 'GEN',
          'body': '내가 쓴 댓글',
          'likeCount': 1,
          'createdAt': '2026-08-26T21:00:00',
        },
        {
          'id': 8,
          'postId': 2,
          'postTitle': '전체 게시판 원글',
          'boardTeamId': null,
          'boardTeamCode': null,
          'body': '또 하나',
          'likeCount': 0,
          'createdAt': '2026-08-26T20:00:00',
        },
      ],
    });

    // 목록에 게시판이 섞여 나오므로 줄마다 구분이 되어야 한다.
    expect(page.comments[0].boardTeamId, 23);
    expect(page.comments[0].boardTeamCode, 'GEN');
    expect(page.comments[1].boardTeamId, isNull);
    expect(page.comments[1].boardTeamCode, isNull);
  });
}
