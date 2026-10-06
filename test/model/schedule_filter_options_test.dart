import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/schedule_filter_options.dart';

/// `/api/mobile/schedules/filters` 응답 파싱.
///
/// `seasons` 는 서버가 **연도+스플릿** 단위로 준다(`2026 Split 1/2/3`).
/// 시즌 필터는 연도 단위라(`seasonYear` 파라미터) 연도만 추려 쓴다.
/// 예전엔 이 필드를 아예 파싱하지 않고 앱이 `['2025','2026']` 을 하드코딩해
/// 썼다 — 서버가 이미 주는 값을 받아놓고 버리고 있었다.
void main() {
  group('seasons → seasonYears', () {
    test('연도+스플릿 응답에서 연도만 중복 없이 오름차순으로 뽑는다', () {
      // prod 실제 응답 형태(2026-10-02).
      final options = ScheduleFilterOptions.fromJson({
        'defaultLeague': 'LCK',
        'leagues': [
          {'code': 'ALL', 'name': '전체'},
        ],
        'teams': [],
        'seasons': [
          {'year': 2026, 'split': 'Split 1', 'label': '2026 Split 1'},
          {'year': 2026, 'split': 'Split 2', 'label': '2026 Split 2'},
          {'year': 2026, 'split': 'Split 3', 'label': '2026 Split 3'},
          {'year': 2025, 'split': 'Split 3', 'label': '2025 Split 3'},
        ],
      });

      expect(options.seasonYears, [2025, 2026]);
    });

    test('seasons 가 없으면 빈 목록 — 호출부가 폴백한다', () {
      final options = ScheduleFilterOptions.fromJson({
        'defaultLeague': 'LCK',
        'leagues': [],
        'teams': [],
      });

      expect(options.seasonYears, isEmpty);
    });

    test('year 가 없거나 형식이 다른 항목은 건너뛴다', () {
      final options = ScheduleFilterOptions.fromJson({
        'defaultLeague': 'LCK',
        'leagues': [],
        'teams': [],
        'seasons': [
          {'split': 'Split 1'},
          {'year': null},
          {'year': 2027, 'split': 'Split 1'},
        ],
      });

      expect(options.seasonYears, [2027]);
    });
  });

  group('리그 메타(standings·alarm·iconUrl)', () {
    test('서버가 준 값을 그대로 파싱하고 빈 iconUrl 은 null 로 본다', () {
      final options = ScheduleFilterOptions.fromJson({
        'defaultLeague': 'LCK',
        'leagues': [
          {'code': 'ALL', 'name': '전체', 'standings': null, 'alarm': false},
          {
            'code': 'LCK',
            'name': 'LCK',
            'standings': true,
            'alarm': true,
            'iconUrl': 'https://x/lck.png',
          },
          {'code': 'LPL', 'name': 'LPL', 'alarm': false, 'iconUrl': ''},
        ],
        'teams': [],
      });

      final lck = options.leagues[1];
      expect(lck.standings, isTrue);
      expect(lck.alarm, isTrue);
      expect(lck.iconUrl, 'https://x/lck.png');
      final lpl = options.leagues[2];
      expect(lpl.standings, isNull);
      expect(lpl.iconUrl, isNull);
      expect(options.hasLeagueMeta, isTrue);
    });

    test('필드가 없는 구버전 응답은 hasLeagueMeta 가 false', () {
      final options = ScheduleFilterOptions.fromJson({
        'defaultLeague': 'LCK',
        'leagues': [
          {'code': 'LCK', 'name': 'LCK'},
        ],
        'teams': [],
      });

      expect(options.hasLeagueMeta, isFalse);
      expect(options.leagues.single.alarm, isNull);
    });
  });
}
