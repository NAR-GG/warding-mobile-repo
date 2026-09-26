import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/components/nar_live_dot.dart';
import 'package:warding/components/team_logo.dart';
import 'package:warding/screens/home/component/home_today_matches_section.dart';

import 'home_test_harness.dart';

/// 오늘 경기 스트립 — 마지막 카드("일정 전체")를 누르면 일정 탭으로 간다
/// (spec 사용자 흐름 4). 화면 전환은 HomeScreen 이 콜백으로 맡는다.
void main() {
  testWidgets('마지막 "일정 전체" 카드는 점선이고 누르면 onSeeSchedule', (tester) async {
    setUpHomeApi();
    var opened = 0;
    await pumpHomeSection(
      tester,
      section: (vm) => HomeTodayMatchesSection(
        viewModel: vm,
        scale: 1,
        onSeeSchedule: () => opened++,
      ),
    );

    final card = find.byKey(HomeTodayMatchesSection.seeScheduleCardKey);
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.descendant(of: card, matching: find.byType(DashedBorder)),
      findsOneWidget,
    );
    await tester.tap(card);
    expect(opened, 1);
  });

  testWidgets('경기 카드는 LIVE 배지에 깜박이는 점을 달고 팀마다 로고 칸을 둔다', (tester) async {
    setUpHomeApi();
    await pumpHomeSection(
      tester,
      section: (vm) => HomeTodayMatchesSection(viewModel: vm, scale: 1),
    );

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byType(NarLiveDot), findsOneWidget);
    expect(find.byType(TeamLogo), findsNWidgets(2));
    expect(tester.getSize(find.byType(TeamLogo).first), const Size(24, 24));
  });
}
