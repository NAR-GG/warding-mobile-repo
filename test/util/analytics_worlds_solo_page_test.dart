import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/analytics_events.dart';

/// 월즈 솔랭이 **내 선수와 다른 화면으로 집계**되는지 고정한다.
///
/// 두 화면은 `MyPlayersScreen(worlds: true/false)` 로 **같은 화면 코드**를
/// 쓴다. 그래서 라우트 이름도 둘 다 `my_players` 로 붙어 있었고,
/// `page_view` 가 합쳐져 월즈 솔랭 진입을 따로 볼 수 없었다
/// (2026-10-21 알림의 `my_players 391` 은 두 화면을 합친 수였다).
///
/// 같은 화면을 재사용하는 구조라 **나중에 누가 라우트 이름을 다시 하나로
/// 합치기 쉽다.** 그러면 집계가 조용히 되돌아가므로 값으로 박아 둔다.
void main() {
  test('월즈 솔랭은 내 선수와 다른 page 값을 쓴다', () {
    expect(AnalyticsPage.worldsSolo, 'worlds_solo');
    expect(AnalyticsPage.worldsSolo, isNot(AnalyticsPage.myPlayers));
  });

  test('알림 토글 프로퍼티 키는 값 규칙(소문자·언더바)을 따른다', () {
    // 규칙이 깨지면 믹스패널에서 다른 키로 갈라져 집계가 쪼개진다.
    for (final key in [AnalyticsProp.alarmStart, AnalyticsProp.alarmEnd]) {
      expect(key, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: key);
    }
    expect(AnalyticsProp.alarmStart, 'alarm_start');
    expect(AnalyticsProp.alarmEnd, 'alarm_end');
  });
}
