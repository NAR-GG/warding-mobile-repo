import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/game_record.dart';

void main() {
  group('GameRecord.fromJson', () {
    test('선수 목록을 파싱한다', () {
      final record = GameRecord.fromJson({
        'players': [
          <String, dynamic>{
            'side': 'Blue',
            'wardsPlaced': 10,
            'wardsKilled': 2,
          },
          <String, dynamic>{'side': 'Red', 'wardsPlaced': 20, 'wardsKilled': 5},
        ],
      });

      expect(record.players, hasLength(2));
      expect(record.players.first.side, 'Blue');
      expect(record.players.first.wardsPlaced, 10);
      expect(record.players.first.wardsKilled, 2);
    });

    test('players 가 없으면 빈 리스트', () {
      final record = GameRecord.fromJson(<String, dynamic>{});
      expect(record.players, isEmpty);
    });
  });

  group('GameRecord.wardsForSide', () {
    test('같은 side 선수들의 와드 설치·파괴를 합산한다', () {
      final record = GameRecord(
        players: const [
          PlayerRecord(side: 'Blue', wardsPlaced: 10, wardsKilled: 2),
          PlayerRecord(side: 'Blue', wardsPlaced: 15, wardsKilled: 3),
          PlayerRecord(side: 'Red', wardsPlaced: 20, wardsKilled: 5),
        ],
      );

      final (bluePlaced, blueKilled) = record.wardsForSide('Blue');
      expect(bluePlaced, 25);
      expect(blueKilled, 5);

      final (redPlaced, redKilled) = record.wardsForSide('Red');
      expect(redPlaced, 20);
      expect(redKilled, 5);
    });

    test('대소문자를 구분하지 않는다', () {
      final record = GameRecord(
        players: const [
          PlayerRecord(side: 'blue', wardsPlaced: 10, wardsKilled: 2),
        ],
      );

      final (placed, killed) = record.wardsForSide('BLUE');
      expect(placed, 10);
      expect(killed, 2);
    });

    test('해당 side 선수가 없으면 0/0', () {
      const record = GameRecord(players: []);
      final (placed, killed) = record.wardsForSide('Blue');
      expect(placed, 0);
      expect(killed, 0);
    });
  });
}
