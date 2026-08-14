import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/schedule/component/calendar_month_label.dart';
import 'package:warding/screens/schedule/component/schedule_calendar.dart';
import 'package:warding/screens/schedule/component/schedule_header.dart';

void main() {
  /// 라벨을 실제 쓰이는 자리 그대로 — ScheduleHeader 의 monthLabelWidget 으로
  /// 넣어 띄운다. 헤더는 Row > Expanded > Column(min) 구조라, 라벨이 스스로
  /// 크기를 못 정하면 여기서 레이아웃이 터진다.
  Future<void> pumpInHeader(WidgetTester tester, double page) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ScheduleHeader(
            monthLabel: '2026.08',
            monthLabelWidget: CalendarMonthLabel(
              progress: CalendarScrollProgress(
                month: DateTime(2026, 8),
                page: page,
              ),
              scale: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 라벨 위젯이 차지한 사각형.
  Rect labelRect(WidgetTester tester) =>
      tester.getRect(find.byType(CalendarMonthLabel));

  testWidgets('정착 상태(page 0)에서 레이아웃 예외 없이 그려진다', (tester) async {
    await pumpInHeader(tester, 0);

    expect(tester.takeException(), isNull);
    expect(find.text('2026.08'), findsOneWidget);
  });

  testWidgets('스와이프 중간(page 0.5)에도 레이아웃 예외가 없다', (tester) async {
    await pumpInHeader(tester, 0.5);

    expect(tester.takeException(), isNull);
    // 나가는 달과 들어오는 달이 함께 그려진다.
    expect(find.text('2026.08'), findsOneWidget);
    expect(find.text('2026.09'), findsOneWidget);
  });

  testWidgets('이전 달 방향(page -0.4)에도 레이아웃 예외가 없다', (tester) async {
    await pumpInHeader(tester, -0.4);

    expect(tester.takeException(), isNull);
    // page -0.4 는 7월과 8월 사이 — floor 는 -1 이라 7월이 나가는 쪽.
    expect(find.text('2026.07'), findsOneWidget);
    expect(find.text('2026.08'), findsOneWidget);
  });

  testWidgets('스와이프 내내 라벨 폭이 변하지 않는다 — 헤더가 흔들리지 않게', (tester) async {
    await pumpInHeader(tester, 0);
    final settled = labelRect(tester);

    // 0 → 1 사이를 훑으며 폭이 그대로인지 본다. 폭이 프레임마다 달라지면
    // 옆 아이콘이 밀리면서 라벨이 깜박이는 것처럼 보인다.
    for (final page in [0.1, 0.25, 0.5, 0.75, 0.9]) {
      await pumpInHeader(tester, page);
      expect(tester.takeException(), isNull);
      final rect = labelRect(tester);
      expect(
        rect.width,
        closeTo(settled.width, 0.5),
        reason: 'page=$page 에서 폭이 달라졌다',
      );
      expect(rect.height, closeTo(settled.height, 0.5));
      // 왼쪽 시작 위치도 고정 — 좌측 정렬이 흔들리면 안 된다.
      expect(rect.left, closeTo(settled.left, 0.5));
    }
  });

  testWidgets('자릿수가 늘어나는 전환(2026.09 → 2026.10)에도 폭이 그대로다', (tester) async {
    // 9월 기준으로 10월로 넘어가는 구간.
    Future<void> pumpAt(double page) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScheduleHeader(
              monthLabel: '2026.09',
              monthLabelWidget: CalendarMonthLabel(
                progress: CalendarScrollProgress(
                  month: DateTime(2026, 9),
                  page: page,
                ),
                scale: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpAt(0);
    final settled = labelRect(tester);

    for (final page in [0.3, 0.6, 0.99]) {
      await pumpAt(page);
      expect(tester.takeException(), isNull);
      expect(labelRect(tester).width, closeTo(settled.width, 0.5));
    }
  });

  testWidgets('라벨은 한 줄 높이를 넘지 않는다 — 헤더 요약문을 밀지 않게', (tester) async {
    await pumpInHeader(tester, 0);
    final settled = labelRect(tester);

    await pumpInHeader(tester, 0.5);
    // 두 줄이 겹쳐 그려져도 차지하는 높이는 한 줄 그대로여야 한다.
    expect(labelRect(tester).height, closeTo(settled.height, 0.5));
  });
}
