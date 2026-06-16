import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_badge.dart';
import 'package:warding/util/rating_mapping.dart';

void main() {
  group('sideFromTeamSide', () {
    test('BLUE → blue, RED → red, 그 외 → blue', () {
      expect(sideFromTeamSide('BLUE'), BadgeSide.blue);
      expect(sideFromTeamSide('RED'), BadgeSide.red);
      expect(sideFromTeamSide('unknown'), BadgeSide.blue);
    });
  });

  group('positionFromRole', () {
    test('역할 코드를 한글 포지션으로 변환', () {
      expect(positionFromRole('TOP'), '탑');
      expect(positionFromRole('JUNGLE'), '정글');
      expect(positionFromRole('MID'), '미드');
      expect(positionFromRole('BOTTOM'), '원딜');
      expect(positionFromRole('SUPPORT'), '서폿');
    });

    test('알 수 없는 역할은 원본을 반환', () {
      expect(positionFromRole('FLEX'), 'FLEX');
    });
  });

  group('ratingTimeAgo', () {
    test('1분 미만은 방금', () {
      final now = DateTime(2026, 6, 16, 12, 0, 0);
      expect(ratingTimeAgo(DateTime(2026, 6, 16, 11, 59, 30), now: now), '방금');
    });

    test('분/시간/일 단위', () {
      final now = DateTime(2026, 6, 16, 12, 0, 0);
      expect(ratingTimeAgo(DateTime(2026, 6, 16, 11, 58), now: now), '2분 전');
      expect(ratingTimeAgo(DateTime(2026, 6, 16, 9, 0), now: now), '3시간 전');
      expect(ratingTimeAgo(DateTime(2026, 6, 14, 12, 0), now: now), '2일 전');
    });

    test('7일 이상은 YYYY.MM.DD', () {
      final now = DateTime(2026, 6, 16, 12, 0, 0);
      expect(ratingTimeAgo(DateTime(2026, 6, 1, 9, 5), now: now), '2026.06.01');
    });

    test('null 이면 빈 문자열', () {
      expect(ratingTimeAgo(null), '');
    });
  });
}
