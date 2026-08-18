import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/schedule_match.dart';

import '../support/l10n_test_setup.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        'matchId': 'm1',
        'scheduledTime': '17:00',
        'leagueName': 'LCK',
        'matchTitle': 'T1 vs GEN',
        'matchStatus': 'inProgress',
        'blueTeam': {'teamName': 'T1', 'teamCode': 'T1', 'teamImageUrl': '', 'score': 0},
        'redTeam': {'teamName': 'GEN', 'teamCode': 'GEN', 'teamImageUrl': '', 'score': 0},
      };

  test('streamLinks 를 파싱하고 effectiveStreamLinks 로 그대로 노출한다', () {
    final json = baseJson()
      ..['liveStreamUrl'] = 'https://chzzk.naver.com/abc'
      ..['streamLinks'] = [
        {
          'provider': 'chzzk',
          'label': '치지직',
          'description': 'LCK 공식 채널 · 한국어',
          'url': 'https://chzzk.naver.com/abc',
        },
        {
          'provider': 'soop',
          'label': 'SOOP',
          'description': 'aflol · 한국어',
          'url': 'https://play.sooplive.co.kr/aflol',
        },
      ];

    final match = ScheduleMatch.fromJson(json);

    expect(match.streamLinks, hasLength(2));
    expect(match.effectiveStreamLinks, hasLength(2));
    expect(match.effectiveStreamLinks.first.provider, 'chzzk');
    expect(match.effectiveStreamLinks.last.url, 'https://play.sooplive.co.kr/aflol');
  });

  // 폴백 링크의 label 을 appStrings 로 채우므로 로케일 호스트가 필요하다.
  testWidgets('streamLinks 가 없으면(구버전 서버) liveStreamUrl 하나로 폴백한다', (
    WidgetTester tester,
  ) async {
    await pumpAppStringsHost(tester);

    final json = baseJson()..['liveStreamUrl'] = 'https://play.sooplive.co.kr/aflol';

    final match = ScheduleMatch.fromJson(json);

    expect(match.streamLinks, isEmpty);
    expect(match.effectiveStreamLinks, hasLength(1));
    expect(match.effectiveStreamLinks.first.url, 'https://play.sooplive.co.kr/aflol');
  });

  test('링크가 아무것도 없으면 effectiveStreamLinks 는 빈 목록이다', () {
    final match = ScheduleMatch.fromJson(baseJson());

    expect(match.effectiveStreamLinks, isEmpty);
  });
}
