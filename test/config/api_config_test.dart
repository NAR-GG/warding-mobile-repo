import 'package:flutter_test/flutter_test.dart';
import 'package:warding/config/api_config.dart';

void main() {
  // 서버 목록은 static 상태라 테스트 사이에 넘어간다 — 매번 되돌린다.
  tearDown(ApiConfig.resetLeagueCodes);

  group('league=ALL 치환 목록은 서버를 따라간다', () {
    test('서버 목록을 받으면 그걸로 펼친다 — 앱에 없던 새 리그도 포함된다', () {
      ApiConfig.updateLeagueCodes(const ['LCK', 'LPL', 'NEW_LEAGUE_2027']);

      final url = ApiConfig.mobileSchedulesUrl(
        date: '2026-07-27',
        leagues: const ['ALL'],
      );

      // 앱 폴백 목록에 없는 리그도 서버가 주면 그대로 나간다 — 이게 핵심이다.
      expect(url, contains('league=NEW_LEAGUE_2027'));
      expect(url, contains('league=LCK'));
      // 서버가 안 준 리그는 빠진다(폴백과 섞이지 않는다).
      expect(url, isNot(contains('league=CBLOL')));
    });

    test("'ALL' 과 빈 값은 치환 목록에서 걸러낸다", () {
      ApiConfig.updateLeagueCodes(const ['ALL', '', 'LCK']);

      expect(ApiConfig.allRealLeagueCodes, const ['LCK']);
    });

    test('빈 목록은 무시하고 폴백을 유지한다 — 조회 실패로 목록이 비는 걸 막는다', () {
      ApiConfig.updateLeagueCodes(const []);

      expect(ApiConfig.allRealLeagueCodes, ApiConfig.fallbackLeagueCodes);
    });

    test('아직 못 받았으면 폴백을 쓴다', () {
      expect(ApiConfig.allRealLeagueCodes, ApiConfig.fallbackLeagueCodes);
    });
  });

  group('mobileSchedulesUrl', () {
    test('league가 ALL 하나뿐이면 실제 리그 코드 전체를 나열한다', () {
      final url = ApiConfig.mobileSchedulesUrl(
        date: '2026-07-27',
        leagues: const ['ALL'],
      );

      expect(url, isNot(contains('league=ALL')));
      for (final code in [
        'LCK', 'LPL', 'LEC', 'LCS', 'MSI', 'WORLDS',
        'EWC', 'FIRST_STAND', 'KESPA', 'CBLOL', 'LCP', 'ASIAN_GAMES',
        'DEMACIA_CUP',
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

  group('noticeViewUrl', () {
    test('공지 id 로 조회수 증가 경로를 만든다', () {
      expect(ApiConfig.noticeViewUrl(7), endsWith('/notices/7/view'));
    });
  });
}
