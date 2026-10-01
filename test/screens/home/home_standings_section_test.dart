import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/components/nar_chip.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_standings_section.dart';
import 'package:warding/styles/app_colors.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

/// 순위표 — 데이터 없는 리그(LPL·LEC·LCS)와 월즈(출시 보류 — 스위스 전적·
/// 토너먼트 대진 카드는 구현돼 있지만 칩은 비활성)는 점선 칩이고 누를 수
/// 없다. 1위 순위 숫자만 메인 보라색으로 강조한다(2026-09-29 결정 — 팀
/// 이름 줄 등 나머지는 다른 행과 동일). 로딩·에러는 그리지 않는다.
void main() {
  // 리그 칩 — 라벨 텍스트를 품은 NarChip.
  Finder chip(String code) =>
      find.ancestor(of: find.text(code), matching: find.byType(NarChip));

  testWidgets('LPL·LEC·LCS·월즈 칩은 점선이고 눌러도 리그가 바뀌지 않는다', (tester) async {
    final server = setUpHomeApi();
    final vm = await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
    );

    // 리그 칩 줄은 가로 스크롤이라 맨 끝 '월즈' 칩은 기본 화면 밖이다.
    final chipScroller = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    await tester.dragUntilVisible(
      chip('월즈'),
      chipScroller,
      const Offset(-50, 0),
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

  testWidgets('"전체 경기"는 리그와 무관하게 항상 보이고 누르면 콜백을 넘긴다', (tester) async {
    setUpHomeApi();
    var tapped = 0;
    await pumpHomeSection(
      tester,
      section: (vm) => HomeStandingsSection(
        viewModel: vm,
        scale: 1,
        onSeeAllBracket: () => tapped++,
      ),
    );

    expect(find.text('전체 경기'), findsOneWidget);
    await tester.tap(find.text('전체 경기'));
    expect(tapped, 1);
  });

  testWidgets('1위 순위 숫자만 메인 보라색이고 나머지 줄은 다른 행과 같은 스타일이다', (tester) async {
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
    expect(first.style?.color, AppColors.narChipActive);
    expect(second.style?.color, isNot(AppColors.narChipActive));

    // 팀 이름 줄은 같다(팀 코드는 로고 대체 글자와 겹쳐 이름으로 비교).
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

  // 월즈 칩이 다시 비활성(live:false)이라 selectLeague('WORLDS')가 무시돼
  // 이 경로로 도달 불가 — 칩을 다시 켜면 같이 되살린다.
  testWidgets(
    '월즈 카드(스위스 전적·토너먼트 대진) 둘 다 RenderFlex 오버플로우 없이 그려진다',
    skip: true,
    (tester) async {
      // HOME_MOCKS 가 꺼져 있으면 worldsStandings 가 null 이라 카드 자리가
      // 비어 이 테스트가 의미 없다 — --dart-define=HOME_MOCKS=true 로만 돈다.
      if (!kHomeMocks) {
        return;
      }
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = originalOnError);

      setUpHomeApi();
      final vm = await pumpHomeSection(
        tester,
        section: (vm) => HomeStandingsSection(viewModel: vm, scale: 1),
      );
      vm.selectLeague('WORLDS');
      await tester.pumpAndSettle();

      // 기본은 스위스 전적.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        errors.where((e) => e.exception.toString().contains('RenderFlex')),
        isEmpty,
        reason: '스위스 전적 카드에서 오버플로우 발생: $errors',
      );

      vm.toggleWorldsView();
      expect(vm.worldsView, WorldsStandingsView.knockout);
      await tester.pumpAndSettle();

      expect(
        errors.where((e) => e.exception.toString().contains('RenderFlex')),
        isEmpty,
        reason: '토너먼트 대진 카드에서 오버플로우 발생: $errors',
      );
    },
  );
}
