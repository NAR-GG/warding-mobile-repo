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

  test('메타 없는 응답은 무시하고 폴백을 유지한다', () {
    LeagueMeta.update(_options(const [FilterLeague(code: 'LCK', name: 'LCK')]));

    expect(LeagueMeta.alarmEnabled('LCK'), isTrue);
    expect(LeagueMeta.alarmEnabled('MSI'), isTrue);
  });
}
