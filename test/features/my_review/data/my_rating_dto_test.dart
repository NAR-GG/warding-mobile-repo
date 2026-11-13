import 'package:flutter_test/flutter_test.dart';
import 'package:warding/features/my_review/data/models/my_rating_dto.dart';

void main() {
  test('fromJson: 페이지·항목·매치정보 파싱', () {
    final json = {
      'ratings': [
        {
          'ratingId': 7,
          'gameId': '113990000000000001',
          'participantId': 3,
          'playerId': 42,
          'playerName': 'Faker',
          'playerImageUrl': 'https://img/faker.png',
          'teamSide': 'BLUE',
          'role': 'MID',
          'championName': 'Galio',
          'rating': 5,
          'comment': '역시 페이커',
          'createdAt': '2026-04-20T18:00:00',
          'updatedAt': '2026-04-20T18:00:00',
          'match': {
            'matchId': 'm-1',
            'gameOrder': 2,
            'leagueName': 'LCK 2025 스프링',
            'matchTitle': 'DNS vs T1',
            'blueTeamCode': 'DNS',
            'redTeamCode': 'T1',
            'matchDate': '2026-04-01T18:00:00',
          },
        },
      ],
      'page': 0,
      'size': 20,
      'totalElements': 3,
      'totalPages': 1,
    };

    final list = MyRatingListDto.fromJson(json);

    expect(list.totalElements, 3);
    // hasMore 는 도메인 관심사라 Entity(MyReviewPage) 가 갖는다.
    expect(list.page + 1 < list.totalPages, isFalse);
    expect(list.ratings, hasLength(1));
    final item = list.ratings.first;
    expect(item.ratingId, 7);
    expect(item.playerName, 'Faker');
    expect(item.rating, 5);
    expect(item.comment, '역시 페이커');
    expect(item.match, isNotNull);
    expect(item.match!.leagueName, 'LCK 2025 스프링');
    expect(item.match!.gameOrder, 2);
  });

  test('fromJson: match 가 null 이고 다음 페이지가 있을 때', () {
    final json = {
      'ratings': [
        {
          'ratingId': 1,
          'gameId': 'g',
          'participantId': 1,
          'playerId': 1,
          'playerName': 'P',
          'playerImageUrl': '',
          'teamSide': 'RED',
          'role': 'TOP',
          'championName': 'C',
          'rating': 4,
          'comment': null,
          'createdAt': '2026-04-20T18:00:00',
          'updatedAt': '2026-04-20T18:00:00',
          'match': null,
        },
      ],
      'page': 0,
      'size': 20,
      'totalElements': 50,
      'totalPages': 3,
    };

    final list = MyRatingListDto.fromJson(json);
    expect(list.page + 1 < list.totalPages, isTrue);
    expect(list.ratings.first.match, isNull);
    expect(list.ratings.first.comment, isNull);
  });
}
