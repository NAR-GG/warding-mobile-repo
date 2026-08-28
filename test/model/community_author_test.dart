import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/community_author.dart';

void main() {
  test('fromJson이 필드를 그대로 매핑한다', () {
    final author = CommunityAuthor.fromJson(const {
      'memberId': 7,
      'nickname': '이름#0001',
      'profileImageUrl': 'https://example.com/p.png',
      'teamId': 1,
      'teamCode': 'T1',
      'teamImageUrl': 'https://example.com/t.png',
    });

    expect(author.memberId, 7);
    expect(author.nickname, '이름#0001');
    expect(author.teamId, 1);
    expect(author.teamCode, 'T1');
    expect(author.teamImageUrl, 'https://example.com/t.png');
  });

  test('팀 정보가 없으면 null', () {
    final author = CommunityAuthor.fromJson(const {
      'memberId': 7,
      'nickname': '무소속',
    });

    expect(author.teamId, isNull);
    expect(author.teamCode, isNull);
    expect(author.teamImageUrl, isNull);
  });
}
