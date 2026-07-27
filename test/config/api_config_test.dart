import 'package:flutter_test/flutter_test.dart';
import 'package:warding/config/api_config.dart';

void main() {
  group('mobileSchedulesUrl', () {
    test('league가 ALL 하나뿐이면 실제 리그 코드 전체를 나열한다', () {
      final url = ApiConfig.mobileSchedulesUrl(
        date: '2026-07-27',
        leagues: const ['ALL'],
      );

      expect(url, isNot(contains('league=ALL')));
      for (final code in [
        'LCK', 'LPL', 'LEC', 'LCS', 'MSI', 'WORLDS',
        'EWC', 'FIRST_STAND', 'KESPA', 'CBLOL', 'LCP',
      ]) {
        expect(url, contains('league=$code'));
      }
    });

    test('실제 리그를 여러 개 골랐으면 그대로 반복 파라미터로 보낸다', () {
      final url = ApiConfig.mobileSchedulesUrl(
        date: '2026-07-27',
        leagues: const ['LCK', 'LPL'],
      );

      expect(url, contains('league=LCK'));
      expect(url, contains('league=LPL'));
      expect(url, isNot(contains('league=ALL')));
    });

    test('리그 하나만 골랐으면 그 리그만 보낸다', () {
      final url = ApiConfig.mobileSchedulesUrl(
        date: '2026-07-27',
        leagues: const ['LCK'],
      );

      expect(url, contains('league=LCK'));
      expect(url, isNot(contains('league=LPL')));
    });
  });
}
