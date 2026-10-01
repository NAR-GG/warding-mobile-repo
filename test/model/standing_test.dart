import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/standing.dart';

void main() {
  test('지원 리그: groups·rows를 그대로 파싱한다', () {
    final result = StandingsResult.fromJson({
      'league': 'LCK',
      'supported': true,
      'reason': null,
      'scopeLabel': '정규시즌',
      'groups': [
        {
          'name': '레전드 그룹',
          'rows': [
            {
              'rank': 1,
              'teamCode': 'GEN',
              'teamName': 'Gen.G',
              'imageUrl': 'https://x/gen.png',
              'wins': 19,
              'losses': 7,
              'setDiff': 22,
            },
          ],
        },
      ],
    });

    expect(result.supported, isTrue);
    final row = result.groups.single.rows.single;
    expect(row.rank, 1);
    expect(row.teamCode, 'GEN');
    expect(row.setDiff, 22);
  });

  test('필드 누락에도 죽지 않고 기본값으로 채운다', () {
    final result = StandingsResult.fromJson(const {});
    expect(result.supported, isFalse);
    expect(result.groups, isEmpty);
  });
}
