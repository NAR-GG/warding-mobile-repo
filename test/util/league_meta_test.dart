import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/schedule_filter_options.dart';
import 'package:warding/util/league_meta.dart';

ScheduleFilterOptions _options(List<FilterLeague> leagues) =>
    ScheduleFilterOptions(
      defaultLeague: 'LCK',
      leagues: leagues,
      teams: const [],
    );

void main() {
  tearDown(LeagueMeta.reset);

  test('서버 메타를 받기 전에는 하드코딩 알림 리그로 폴백한다', () {
    expect(LeagueMeta.alarmEnabled('LCK'), isTrue);
    expect(LeagueMeta.alarmEnabled('DEMACIA_CUP'), isTrue);
    expect(LeagueMeta.alarmEnabled('LPL'), isFalse);
    expect(LeagueMeta.iconUrl('LCK'), isNull);
  });

  test('서버 메타를 받으면 그 값이 폴백을 덮는다', () {
    LeagueMeta.update(
      _options(const [
        FilterLeague(code: 'LCK', name: 'LCK', alarm: false),
        FilterLeague(
          code: 'LPL',
          name: 'LPL',
          alarm: true,
          iconUrl: 'https://x/lpl.png',
        ),
      ]),
    );

    expect(LeagueMeta.alarmEnabled('LCK'), isFalse);
    expect(LeagueMeta.alarmEnabled('LPL'), isTrue);
    expect(LeagueMeta.iconUrl('lpl'), 'https://x/lpl.png');
    expect(LeagueMeta.iconUrl('LCK'), isNull);
  });

  // contains 로 보면 코드가 다른 코드의 접두사인 리그에서 오탐이 난다 —
  // 알림을 끈 리그에 벨이 뜬다.
  test('리그 코드는 부분 문자열이 아니라 전체로 비교한다', () {
    LeagueMeta.update(
      _options(const [
        FilterLeague(code: 'LCK', name: 'LCK', alarm: true),
        FilterLeague(code: 'LCK_CL', name: 'LCK CL', alarm: false),
      ]),
    );

    expect(LeagueMeta.alarmEnabled('LCK'), isTrue);
    expect(
      LeagueMeta.alarmEnabled('LCK_CL'),
      isFalse,
      reason: 'LCK 를 포함한다고 벨이 뜨면 안 된다',
    );
  });

  test('리그 코드 뒤에 시즌 등이 붙어도 코드로 판단한다', () {
    expect(LeagueMeta.alarmEnabled('LCK 2026 Split 3'), isTrue);
    expect(LeagueMeta.alarmEnabled('  lck  '), isTrue);
    expect(LeagueMeta.alarmEnabled('LPL 2026'), isFalse);
  });

  test('메타 없는 응답은 무시하고 폴백을 유지한다', () {
    LeagueMeta.update(_options(const [FilterLeague(code: 'LCK', name: 'LCK')]));

    expect(LeagueMeta.alarmEnabled('LCK'), isTrue);
    expect(LeagueMeta.alarmEnabled('MSI'), isTrue);
  });
}
