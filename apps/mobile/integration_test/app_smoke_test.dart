import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/main.dart' as app;

/// 릴리즈 직전 e2e 스모크 테스트.
///
/// 비로그인 상태를 전제로, 앱이 크래시 없이 스플래시를 지나 로그인 화면까지
/// 도달하는지만 확인한다. 소셜 로그인(카카오/네이버/구글/애플)은 각 SDK의
/// 네이티브 UI를 띄우므로 이 스모크 범위 밖이다 — CLAUDE.md 릴리즈 절차 참고.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('스플래시를 지나 로그인 화면(비로그인)에 도달한다', (tester) async {
    app.main();
    // 스플래시의 최소 표시 시간(600ms) + 프리페치·전환 애니메이션을
    // 여유 있게 기다린다. pumpAndSettle 은 애니메이션이 끝날 때까지 돈다.
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // MaterialApp 자신의 context 는 Localizations 위쪽이라 delegate 가 아직
    // 적용되지 않는다 — 실제 화면(Scaffold)의 context 를 써야 한다.
    final context = tester.element(find.byType(Scaffold).first);
    final l = AppLocalizations.of(context)!;

    expect(find.text(l.kakaoLogin), findsOneWidget);
    expect(find.text(l.naverLogin), findsOneWidget);
  });
}
