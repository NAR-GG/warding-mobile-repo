import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/components/nar_chip.dart';
import 'package:warding/components/nar_chip_multi_select.dart';
import 'package:warding/styles/app_colors.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

double _x(WidgetTester tester, String label) =>
    tester.getTopLeft(find.text(label)).dx;

void main() {
  group('NarChip.disabled', () {
    testWidgets('점선 테두리·narDark200 글자이고 탭을 받지 않는다', (tester) async {
      await tester.pumpWidget(
        _wrap(const Center(child: NarChip.disabled(label: 'LPL'))),
      );
      expect(find.byType(DashedBorder), findsOneWidget);
      expect(tester.getSize(find.byType(NarChip)).height, 34);
      expect(
        tester.widget<Text>(find.text('LPL')).style!.color,
        AppColors.narDark200,
      );
      expect(
        find.descendant(
          of: find.byType(NarChip),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('NarChipMultiSelect 기본', () {
    testWidgets('선택한 칩이 앞으로 정렬된다(기존 동작)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NarChipMultiSelect(
            options: const ['A', 'B', 'C'],
            selectedValues: const {'C'},
            onChanged: (_) {},
          ),
        ),
      );
      expect(_x(tester, 'C'), lessThan(_x(tester, 'A')));
      expect(_x(tester, 'A'), lessThan(_x(tester, 'B')));
    });

    testWidgets('reorderSelected false 면 준 순서를 지킨다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NarChipMultiSelect(
            options: const ['A', 'B', 'C'],
            selectedValues: const {'C'},
            onChanged: (_) {},
            reorderSelected: false,
          ),
        ),
      );
      expect(_x(tester, 'A'), lessThan(_x(tester, 'B')));
      expect(_x(tester, 'B'), lessThan(_x(tester, 'C')));
    });

    testWidgets('disabledOptions 는 점선 칩이고 콜백을 부르지 않는다', (tester) async {
      final calls = <Set<String>>[];
      await tester.pumpWidget(
        _wrap(
          NarChipMultiSelect(
            options: const ['A', 'B'],
            selectedValues: const {},
            onChanged: calls.add,
            disabledOptions: const {'B'},
          ),
        ),
      );
      expect(find.byType(DashedBorder), findsOneWidget);
      await tester.tap(find.text('B'), warnIfMissed: false);
      expect(calls, isEmpty);
      await tester.tap(find.text('A'));
      expect(calls.single, {'A'});
    });

    testWidgets('horizontalPadding 이 스크롤 패딩이 된다', (tester) async {
      await tester.pumpWidget(
        _wrap(
          NarChipMultiSelect(
            options: const ['A'],
            selectedValues: const {},
            onChanged: (_) {},
            horizontalPadding: 20,
          ),
        ),
      );
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.padding!.horizontal, 40);
    });
  });

  group('NarChipMultiSelect.single', () {
    testWidgets('순서를 유지하고 새 칩을 누르면 onSelected 가 한 번 불린다', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(
        _wrap(
          NarChipMultiSelect.single(
            options: const ['A', 'B', 'C'],
            selected: 'C',
            onSelected: picked.add,
          ),
        ),
      );
      expect(_x(tester, 'A'), lessThan(_x(tester, 'B')));
      expect(_x(tester, 'B'), lessThan(_x(tester, 'C')));

      await tester.tap(find.text('B'));
      expect(picked, ['B']);
    });

    testWidgets('이미 선택된 칩을 눌러도 아무 일도 없다', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(
        _wrap(
          NarChipMultiSelect.single(
            options: const ['A', 'B'],
            selected: 'A',
            onSelected: picked.add,
          ),
        ),
      );
      await tester.tap(find.text('A'));
      expect(picked, isEmpty);
    });

    testWidgets('비활성 칩은 누르지 못하고 점선으로 그린다', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(
        _wrap(
          NarChipMultiSelect.single(
            options: const ['LCK', 'LPL'],
            selected: 'LCK',
            onSelected: picked.add,
            disabledOptions: const {'LPL'},
          ),
        ),
      );
      expect(find.byType(DashedBorder), findsOneWidget);
      await tester.tap(find.text('LPL'), warnIfMissed: false);
      expect(picked, isEmpty);
    });
  });
}
