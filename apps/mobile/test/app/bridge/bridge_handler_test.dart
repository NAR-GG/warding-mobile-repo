// 브리지 핸들러 회귀 테스트.
//
// 웹 쪽 `protocol.ts` 와 메시지 형식이 어긋나면 런타임에야 드러난다. 여기서
// **웹이 보내는 실제 JSON 문자열**을 넣어 네이티브 동작이 불리는지 고정한다.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:warding/app/bridge/bridge_handler.dart';
import 'package:warding/app/bridge/bridge_protocol.dart';

/// `runJavaScript` 로 나간 스크립트를 모아 두는 가짜 컨트롤러.
class _FakeController implements WebViewController {
  final scripts = <String>[];

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }

  @override
  noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late _FakeController controller;
  late List<String> log;
  late BridgeHandler bridge;

  setUp(() {
    controller = _FakeController();
    log = [];
    bridge = BridgeHandler(
      controller: controller,
      onHeight: (h) => log.add('height:$h'),
      onReady: (at) => log.add('ready'),
      onBack: () => log.add('back'),
      onNavigate: (r) => log.add('navigate:$r'),
      openPhotoViewer: (urls, index) async =>
          log.add('photo:${urls.length}@$index'),
      share: (url, title) async => log.add('share:$url'),
    );
  });

  /// 채널을 거치지 않고 핸들러에 직접 넣는다 — `attach()` 는 플랫폼 채널이라
  /// 단위 테스트에서 못 쓴다.
  Future<void> send(Map<String, Object?> json) async {
    // ignore: invalid_use_of_visible_for_testing_member
    await bridge.handleForTest(jsonEncode(json));
  }

  group('Stage A', () {
    test('height 를 전달한다', () async {
      await send({'stage': 'a', 'type': 'height', 'height': 420});
      expect(log, ['height:420.0']);
    });

    test('높이가 0 이하면 무시한다', () async {
      await send({'stage': 'a', 'type': 'height', 'height': 0});
      expect(log, isEmpty);
    });

    test('ready·back·navigate', () async {
      await send({'stage': 'a', 'type': 'ready', 'at': 1});
      await send({'stage': 'a', 'type': 'back'});
      await send({'stage': 'a', 'type': 'navigate', 'route': '/x'});
      expect(log, ['ready', 'back', 'navigate:/x']);
    });

    test('빈 route 는 무시한다', () async {
      await send({'stage': 'a', 'type': 'navigate', 'route': ''});
      expect(log, isEmpty);
    });

    test('모르는 type 이어도 죽지 않는다', () async {
      await send({'stage': 'a', 'type': 'nope'});
      expect(log, isEmpty);
    });
  });

  group('Stage C', () {
    test('사진 뷰어를 열고 성공을 돌려준다', () async {
      await send({
        'stage': 'c',
        'id': 'c1',
        'method': 'openPhotoViewer',
        'urls': ['a', 'b'],
        'index': 1,
      });
      expect(log, ['photo:2@1']);
      // 페이로드가 JS 문자열 리터럴로 한 번 더 인코딩돼 따옴표가 이스케이프된다.
      expect(controller.scripts.single, contains(r'\"id\":\"c1\"'));
      expect(controller.scripts.single, contains(r'\"ok\":true'));
    });

    test('urls 가 비면 실패를 돌려준다', () async {
      await send({
        'stage': 'c',
        'id': 'c2',
        'method': 'openPhotoViewer',
        'urls': <String>[],
      });
      expect(log, isEmpty);
      expect(controller.scripts.single, contains(r'\"ok\":false'));
    });

    test('모르는 method 는 실패를 돌려준다', () async {
      await send({'stage': 'c', 'id': 'c3', 'method': 'nope'});
      expect(controller.scripts.single, contains(r'\"ok\":false'));
    });

    test('핸들러가 던지면 에러를 전달한다', () async {
      bridge = BridgeHandler(
        controller: controller,
        onHeight: (_) {},
        onReady: (_) {},
        onBack: () {},
        onNavigate: (_) {},
        openPhotoViewer: (_, _) async => throw StateError('실패'),
        share: (_, _) async {},
      );
      await send({
        'stage': 'c',
        'id': 'c4',
        'method': 'openPhotoViewer',
        'urls': ['a'],
      });
      expect(controller.scripts.single, contains(r'\"ok\":false'));
    });

    test('id 가 없으면 아무것도 하지 않는다', () async {
      await send({'stage': 'c', 'method': 'openPhotoViewer', 'urls': ['a']});
      expect(log, isEmpty);
      expect(controller.scripts, isEmpty);
    });
  });

  group('Stage B', () {
    test('env 를 뿌린다', () async {
      await bridge.broadcastEnv(
        const BridgeEnv(
          signedIn: true,
          reduceMotion: false,
          safeAreaTop: 59,
          safeAreaBottom: 34,
        ),
      );
      final script = controller.scripts.single;
      expect(script, contains('__wardingReceive'));
      expect(script, contains(r'\"signedIn\":true'));
    });

    test('auth-changed 를 뿌린다', () async {
      await bridge.broadcastAuthChanged();
      expect(controller.scripts.single, contains('auth-changed'));
    });
  });

  test('깨진 JSON 은 조용히 무시한다', () async {
    // ignore: invalid_use_of_visible_for_testing_member
    await bridge.handleForTest('{ not json');
    expect(log, isEmpty);
  });
}
