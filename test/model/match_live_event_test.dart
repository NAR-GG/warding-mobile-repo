import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/match_live_event.dart';

void main() {
  // objectiveLabel() 이 내부적으로 appStrings(→ navigatorKey.currentContext →
  // WidgetsBinding.instance) 를 건드리므로, 바인딩을 초기화하지 않으면
  // "Binding has not yet been initialized" 로 실패한다.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveEventType.nexus', () {
    test('NEXUS 문자열을 LiveEventType.nexus 로 매핑한다', () {
      final event = MatchLiveEvent.fromJson({
        'type': 'NEXUS',
        'gameTime': '32:10',
        'gameTimeSeconds': 1930,
        'teamSide': 'Blue',
        'teamName': 'T1',
      });

      expect(event.type, LiveEventType.nexus);
    });

    test('objectiveLabel() 은 로케일 문자열이 없으면 Nexus 로 폴백한다', () {
      const event = MatchLiveEvent(
        type: LiveEventType.nexus,
        gameTime: '32:10',
        gameTimeSeconds: 1930,
      );

      expect(event.objectiveLabel(), 'Nexus');
    });

    test('objectiveAsset() 은 nexus.png 를 가리킨다', () {
      const event = MatchLiveEvent(
        type: LiveEventType.nexus,
        gameTime: '32:10',
        gameTimeSeconds: 1930,
      );

      expect(event.objectiveAsset(), 'assets/images/nexus.png');
    });
  });
}
