import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/config/app_globals.dart';
import 'package:warding/l10n/app_localizations.dart';

/// 다국어를 쓰는 코드를 테스트할 때 필요한 준비물 모음.
///
/// 앱 코드는 두 갈래로 문구를 읽는다.
/// - 위젯: `AppLocalizations.of(context)!` — 위젯 트리에 delegate 가 있어야 한다.
/// - 위젯 밖(모델·유틸): `appStrings` — `navigatorKey.currentContext` 를 타므로
///   그 키가 꽂힌 앱이 실제로 떠 있어야 한다.
///
/// 준비 없이 부르면 각각 null check 실패 / 바인딩 미초기화로 터지거나,
/// 조용히 영어 fallback 으로 떨어져 한글 기대값과 어긋난다.

/// 위젯 테스트용 래퍼. 한국어 로케일로 [child] 를 띄운다.
///
/// `AppLocalizations.of(context)` 를 쓰는 위젯은 이 래퍼로 감싸야 한다.
Widget wrapWithL10n(
  Widget child, {
  Locale locale = const Locale('ko'),
  Size? size,
}) {
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: child),
  );
  if (size == null) return app;
  return MediaQuery(data: MediaQueryData(size: size), child: app);
}

/// 위젯 트리 밖에서 [appStrings] 를 쓰는 코드(모델·유틸)를 위한 준비.
///
/// [navigatorKey] 가 꽂힌 빈 앱을 띄워 `appStrings` 가 해당 로케일의
/// [AppLocalizations] 를 찾을 수 있게 한다. `appStrings` 를 거치는 값을
/// 한글로 단언하는 테스트는 단언 전에 이 함수를 await 해야 한다.
///
/// 순수 Dart `test()` 안에서는 쓸 수 없다 — [WidgetTester] 가 필요하므로
/// 해당 테스트를 `testWidgets()` 로 바꿔야 한다.
Future<void> pumpAppStringsHost(
  WidgetTester tester, {
  Locale locale = const Locale('ko'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const SizedBox.shrink(),
    ),
  );
}
