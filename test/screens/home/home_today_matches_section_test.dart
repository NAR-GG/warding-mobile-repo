import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_live_dot.dart';
import 'package:warding/components/team_logo.dart';
import 'package:warding/screens/home/component/home_today_matches_section.dart';

import 'home_test_harness.dart';

/// 오늘 경기 스트립 — 일정 탭으로 가는 길은 헤더의 "일정 전체" 링크 하나뿐이다.
/// 화면 전환은 HomeScreen 이 콜백으로 맡는다.
void main() {
  testWidgets('헤더 "일정 전체"를 누르면 onSeeSchedule', (tester) async {
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

    expect(find.text('일정 전체'), findsOneWidget);
    await tester.tap(find.text('일정 전체'));
    expect(opened, 1);
  });

  testWidgets('오늘 경기가 없으면 섹션 전체를 그리지 않는다', (tester) async {
    final server = setUpHomeApi();
    server.matches = const [];
    await pumpHomeSection(
      tester,
      section: (vm) => HomeTodayMatchesSection(viewModel: vm, scale: 1),
    );

    expect(find.text('오늘의 경기'), findsNothing);
    expect(find.text('일정 전체'), findsNothing);
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
