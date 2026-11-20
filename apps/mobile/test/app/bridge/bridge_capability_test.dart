import 'package:flutter_test/flutter_test.dart';

import 'package:warding/app/bridge/bridge_protocol.dart';
import 'package:warding/app/navigation/webview_navigate.dart';

/// 능력 선언과 실제 구현이 어긋나지 않는지 지킨다.
///
/// **`navigate` 가 능력 목록에 선언돼 있는데 구현이 비어 있었다**(로그만
/// 찍고 끝났다). 웹은 "지원됨" 으로 믿고 보내서 알림 벨이 아무 반응도 하지
/// 않았다 — `share` 는 미선언이라 웹이 폴백을 골랐는데 정반대였다.
///
/// 선언이 곧 계약이다. 코드로 못박아 둔다.
void main() {
  group('능력 선언 ↔ 구현', () {
    test('navigate 를 선언했으면 열 수 있는 대상이 있어야 한다', () {
      if (!kBridgeCapabilities.contains('navigate')) return;
      expect(
        kNativeRoutes,
        isNotEmpty,
        reason: 'navigate 를 선언했는데 kNativeRoutes 가 비었다 — 웹이 보내도 '
            '열 화면이 없다',
      );
    });

    test('share 는 네이티브 구현이 없으므로 선언하지 않는다', () {
      // 구현이 생기면 이 테스트를 지우고 목록에 추가한다.
      expect(kBridgeCapabilities, isNot(contains('share')));
    });

    test('Stage A 메시지는 전부 선언돼 있다', () {
      // 웹이 보내는데 선언이 없으면 웹이 미지원으로 보고 안 쓴다.
      for (final v in BridgeNotify.values) {
        expect(
          kBridgeCapabilities,
          contains(v.name),
          reason: '${v.name} 을 처리하는데 능력 목록에 없다',
        );
      }
    });

    test('선언한 Stage C 는 BridgeCall 에 있어야 한다', () {
      const stageA = {'height', 'ready', 'navigate', 'back'};
      final callNames = BridgeCall.values.map((v) => v.name).toSet();

      for (final name in kBridgeCapabilities) {
        if (stageA.contains(name)) continue;
        expect(
          callNames,
          contains(name),
          reason: '$name 을 선언했는데 BridgeCall 에 없다 — 웹이 불러도 '
              '"모르는 method" 로 실패한다',
        );
      }
    });
  });
}
