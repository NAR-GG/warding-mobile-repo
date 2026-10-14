import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/bottom_action_bar.dart';
import 'package:warding/components/common_button.dart';
import 'package:warding/components/nar_filter_sheet.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/styles/app_colors.dart';

/// 하단 고정 버튼이 앱 공용 [CommonButton] 과 같은 규격인지 본다.
/// 응원 광고 신청은 경기리스트 설정의 '완료'(light), 광고 안내는 경기 일정 필터
/// 시트의 '조회'(primary) 와 같은 버튼이어야 한다.
void main() {
  /// 폭 375 로 고정 — 시안 기준이라 scale 이 1 이 된다.
  Future<void> pumpAt375(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(375, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: AppColors.narDark800,
          body: Column(mainAxisAlignment: MainAxisAlignment.end, children: [child]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// [bar] 안에 있는 공용 버튼의 실제 높이.
  double buttonHeightIn(WidgetTester tester, Finder scope) {
    final button = find.descendant(of: scope, matching: find.byType(CommonButton));
    expect(button, findsOneWidget);
    return tester
        .getSize(find.descendant(of: button, matching: find.byType(Container)))
        .height;
  }

  testWidgets('기본은 경기리스트 설정 완료 버튼과 같은 light 변종이다', (tester) async {
    await pumpAt375(
      tester,
      BottomActionBar(label: '상세 보기', onTap: () {}, scale: 1),
    );

    final bar = find.byType(BottomActionBar);
    final button = find.descendant(of: bar, matching: find.byType(CommonButton));
    expect(tester.widget<CommonButton>(button).variant, CommonButtonVariant.light);
    expect(buttonHeightIn(tester, bar), BottomActionBar.buttonHeight);
  });

  testWidgets('primary 변종은 필터 시트 조회 버튼과 규격이 같다', (tester) async {
    await pumpAt375(
      tester,
      Column(
        children: [
          NarFilterSheet(
            title: '필터',
            onApply: () {},
            child: const SizedBox(height: 20),
          ),
          BottomActionBar(
            label: '광고 신청하기',
            onTap: () {},
            scale: 1,
            variant: CommonButtonVariant.primary,
          ),
        ],
      ),
    );

    final bar = find.byType(BottomActionBar);
    final sheet = find.byType(NarFilterSheet);
    final inBar = find.descendant(of: bar, matching: find.byType(CommonButton));
    final inSheet = find.descendant(of: sheet, matching: find.byType(CommonButton));

    expect(tester.widget<CommonButton>(inBar).variant, CommonButtonVariant.primary);
    expect(tester.widget<CommonButton>(inSheet).variant, CommonButtonVariant.primary);
    expect(buttonHeightIn(tester, bar), buttonHeightIn(tester, sheet));
  });

  testWidgets('scrollInset 은 막 위 여백 + 버튼 + 아래 여백이다', (tester) async {
    expect(BottomActionBar.scrollInset, 40 + BottomActionBar.buttonHeight + 24);
  });
}
