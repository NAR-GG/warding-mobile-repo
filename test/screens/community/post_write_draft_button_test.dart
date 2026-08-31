import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/community/post_write_screen.dart';

/// 헤더의 "임시" 버튼이 실제로 탭에 반응하는지 — 사용자가 "버튼 동작 안 함"을
/// 보고해서 실제 위젯 트리(레이아웃·히트테스트 포함)로 재현한다.
void main() {
  testWidgets('임시 버튼을 탭하면 스낵바로 저장됨을 알린다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PostWriteScreen(boardTeamId: null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '제목');
    await tester.pump();

    final draftButton = find.text('임시');
    expect(draftButton, findsOneWidget, reason: '임시 버튼이 렌더링돼 있어야 한다');

    await tester.tap(draftButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('임시저장했어요.'), findsOneWidget);
  });
}
