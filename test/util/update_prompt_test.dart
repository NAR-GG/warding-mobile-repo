import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrader/upgrader.dart';
import 'package:warding/config/app_globals.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/util/update_prompt.dart';

/// 조회 결과를 고정하는 가짜 upgrader. 실제 구현은 스토어 HTTP 조회와
/// SharedPreferences 를 타므로 테스트에서 띄우지 않는다.
class _FakeUpgrader extends Upgrader {
  _FakeUpgrader({required this.available});

  final bool available;

  @override
  Future<bool> initialize() async => true;

  @override
  bool isUpdateAvailable() => available;
}

void main() {
  /// navigatorKey 가 살아 있는 최소 앱. `checkForUpdate` 는 await 뒤에
  /// navigatorKey 에서 context 를 새로 얻으므로 이 트리가 떠 있어야 한다.
  Widget harness() => MaterialApp(
    navigatorKey: navigatorKey,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ko'),
    home: const Scaffold(body: SizedBox.shrink()),
  );

  group('checkForUpdate', () {
    testWidgets('최신이면 팝업을 띄우지 않는다', (tester) async {
      await tester.pumpWidget(harness());
      var confirmCalls = 0;

      await checkForUpdate(
        upgraderFactory: () => _FakeUpgrader(available: false),
        confirm: (_, _) async {
          confirmCalls++;
          return false;
        },
        openStore: (_) async {},
      );
      await tester.pumpAndSettle();

      expect(confirmCalls, 0);
    });

    testWidgets('새 버전이 있으면 팝업을 띄우고, 확인하면 스토어로 보낸다', (tester) async {
      await tester.pumpWidget(harness());
      UpdatePromptText? shown;
      final opened = <String>[];

      await checkForUpdate(
        upgraderFactory: () => _FakeUpgrader(available: true),
        confirm: (_, text) async {
          shown = text;
          return true;
        },
        openStore: (url) async => opened.add(url),
      );
      await tester.pumpAndSettle();

      expect(shown, isNotNull);
      // 현지화 문구가 실제로 채워져 들어간다(빈 문자열로 뜨면 안 된다).
      expect(shown!.title, isNotEmpty);
      expect(shown!.confirmLabel, isNotEmpty);
      expect(opened, hasLength(1));
    });

    testWidgets('팝업을 닫으면 스토어로 보내지 않는다', (tester) async {
      await tester.pumpWidget(harness());
      final opened = <String>[];

      await checkForUpdate(
        upgraderFactory: () => _FakeUpgrader(available: true),
        confirm: (_, _) async => false,
        openStore: (url) async => opened.add(url),
      );
      await tester.pumpAndSettle();

      expect(opened, isEmpty);
    });

    testWidgets('조회가 실패해도 예외를 밖으로 던지지 않는다', (tester) async {
      await tester.pumpWidget(harness());

      // 스플래시 진입 경로에서 불리므로, 조회 실패가 앱 부팅을 막으면 안 된다.
      await expectLater(
        checkForUpdate(
          upgraderFactory: () => throw StateError('store unreachable'),
          confirm: (_, _) async => true,
          openStore: (_) async {},
        ),
        completes,
      );
    });
  });

  group('알림 간격', () {
    test('매 실행이 아니라 간격을 둔다 — 팝업 피로로 업데이트를 외면하게 만들지 않는다', () {
      // Duration.zero 였을 때: 릴리즈가 2~3일에 한 번 나가는 동안 팝업이 끊기지
      // 않아 "업데이트가 너무 잦다"는 리뷰로 돌아왔다. 2026-10-27 사고에서는
      // 눌러도 아무 일도 없는 팝업이 매 실행마다 떴고 피할 방법이 없었다.
      expect(kUpdateAlertInterval, greaterThan(Duration.zero));
      // 스토어 자동 업데이트(기본 ON)가 도는 데 하루 남짓 걸린다 — 그보다는 길어야
      // 자동으로 될 일을 팝업으로 재촉하지 않는다.
      expect(kUpdateAlertInterval, greaterThan(const Duration(days: 1)));
      expect(kUpdateAlertInterval, const Duration(days: 3));
    });

    test('스토어 URL 은 두 플랫폼 모두 채워져 있다', () {
      expect(kIosStoreUrl, contains('apps.apple.com'));
      expect(kAndroidStoreUrl, contains('play.google.com'));
      expect(kAndroidStoreUrl, contains('com.warding.app'));
    });
  });
}
