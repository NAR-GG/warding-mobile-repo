import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/screens/match_list/component/match_card.dart';

void main() {
  testWidgets('경기 카드의 벨 아이콘을 탭하면 경기 알림 설정 시트가 뜬다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchCard(
            matchId: 'match-1',
            time: '18:00',
            label: '2026 LCK Spring',
            homeName: 'T1',
            awayName: 'GEN',
            homeScore: 1,
            awayScore: 0,
            isLive: true,
            liveSetLabel: 'SET 2 진행중',
          ),
        ),
      ),
    );

    final bellFinder = find.byKey(const Key('matchCardAlarmBell'));
    expect(bellFinder, findsOneWidget);

    await tester.tap(bellFinder);
    await tester.pumpAndSettle();

    expect(find.text('경기 알림 설정'), findsOneWidget);
    expect(find.text('T1'), findsWidgets);
    expect(find.text('GEN'), findsWidgets);
    expect(find.text('세트 시작 알림'), findsOneWidget);
    expect(find.text('세트 종료 알림'), findsOneWidget);
    expect(find.text('라이브 이벤트 알림'), findsOneWidget);

    // 확인 버튼 탭 시 시트가 닫힌다.
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('경기 알림 설정'), findsNothing);
  });
}
