import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/community/post_write_screen.dart';

/// 링크 추가 다이얼로그 — 확인을 누르면 다이얼로그가 닫히는 전환 애니메이션이
/// 끝나기 전에 입력창의 TextEditingController를 dispose하면, 그 사이 몇 프레임
/// 동안 여전히 화면에 남아있는 TextField가 disposed된 controller를 다시 참조하며
/// 크래시가 난다.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('링크 추가 다이얼로그를 확인해 닫아도 닫힘 애니메이션 도중 크래시가 나지 않는다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PostWriteScreen(boardTeamId: null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('링크'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'https://youtu.be/abc123');
    await tester.pump();

    await tester.tap(find.text('추가'));

    // pumpAndSettle이 아니라, 다이얼로그가 닫히는 전환 애니메이션 중간 프레임들을
    // 하나씩 그려본다 — 그 프레임에서 disposed controller를 건드리면 여기서 던진다.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
  });
}
