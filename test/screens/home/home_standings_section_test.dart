import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/screens/home/component/home_standings_section.dart';

import 'home_test_harness.dart';

/// 순위표 — 데이터 없는 리그(LPL·LEC·LCS·월즈)는 점선 칩이고 누를 수 없다.
/// 1위 행은 따로 꾸미지 않는다. 로딩·에러는 그리지 않는다.
void main() {
  Finder chip(String code) => find.byKey(HomeStandingsSection.chipKey(code));

  testWidgets('LPL·LEC·LCS·월즈 칩은 점선이고 눌러도 리그가 바뀌지 않는다', (tester) async {
    final server = setUpHomeApi();
    final vm = await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    for (final code in ['LPL', 'LEC', 'LCS', '월즈']) {
      expect(
        find.descendant(of: chip(code), matching: find.byType(DashedBorder)),
        findsOneWidget,
        reason: '$code 칩은 점선',
      );
      // 탭을 받는 위젯 자체가 없다.
      expect(
        find.descendant(of: chip(code), matching: find.byType(GestureDetector)),
        findsNothing,
        reason: '$code 칩은 누를 수 없다',
      );
      await tester.tap(chip(code), warnIfMissed: false);
      await tester.pump();
      expect(vm.selectedLeague, 'LCK');
    }
    expect(
      server
          .requestsTo('standings')
          .where((u) => u.queryParameters['league'] != 'LCK'),
      isEmpty,
    );

    // LCK 는 실선 칩.
    expect(
      find.descendant(of: chip('LCK'), matching: find.byType(DashedBorder)),
      findsNothing,
    );
  });

  testWidgets('1위 행은 다른 행과 같은 스타일이다', (tester) async {
    setUpHomeApi();
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    final first = tester.widget<Text>(
      find.byKey(HomeStandingsSection.rankKey(1)),
    );
    final second = tester.widget<Text>(
      find.byKey(HomeStandingsSection.rankKey(2)),
    );
    expect(first.style, second.style);

    // 팀 이름 줄도 같다(팀 코드는 로고 대체 글자와 겹쳐 이름으로 비교).
    Text teamText(String name) => tester.widget<Text>(find.text(name));
    expect(teamText('젠지').style, teamText('한화생명e스포츠').style);
  });

  testWidgets('순위 데이터가 없어도 스피너·에러를 그리지 않는다', (tester) async {
    final server = setUpHomeApi();
    server.standingsRows = const [];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('다시 시도'), findsNothing);
    expect(find.textContaining('불러오는 중'), findsNothing);
  });
}
