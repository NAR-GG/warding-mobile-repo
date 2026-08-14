import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/calendar_week_start.dart';
import 'package:warding/screens/schedule/component/calendar_day_cell.dart';
import 'package:warding/screens/schedule/component/calendar_month_grid.dart';

void main() {
  /// 그리드를 [height] 높이 뷰포트에 넣고 띄운다.
  Future<void> pump(
    WidgetTester tester,
    DateTime month, {
    required double height,
    CalendarWeekStart weekStart = CalendarWeekStart.monday,
  }) async {
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
          body: Center(
            child: SizedBox(
              width: 375,
              height: height,
              child: CalendarMonthGrid(
                month: month,
                scale: 1,
                weekStart: weekStart,
                matchesOf: (_) => const [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 그리드에 그려진 날짜 칸들의 세로 범위 (맨 위 ~ 맨 아래).
  ({double top, double bottom}) gridBounds(WidgetTester tester) {
    final cells = find.byType(CalendarDayCell);
    expect(cells, findsWidgets);
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    for (final element in cells.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (rect.top < top) top = rect.top;
      if (rect.bottom > bottom) bottom = rect.bottom;
    }
    return (top: top, bottom: bottom);
  }

  /// 그리드에 그려진 주(행) 수. 칸 수 / 7.
  int weekCount(WidgetTester tester) =>
      find.byType(CalendarDayCell).evaluate().length ~/ 7;

  // 주 수가 서로 다른 달들. 월요일 시작 기준으로 5주·6주·(2월) 4주가 나온다.
  // - 2026.08: 8/1 이 토요일 → 6주
  // - 2026.09: 9/1 이 화요일 → 5주
  // - 2027.02: 2/1 이 월요일, 28일 → 정확히 4주
  const sixWeekMonth = (year: 2026, month: 8);
  const fiveWeekMonth = (year: 2026, month: 9);
  const fourWeekMonth = (year: 2027, month: 2);

  testWidgets('6주짜리 달은 뷰포트를 세로로 꽉 채운다', (tester) async {
    const height = 600.0;
    await pump(
      tester,
      DateTime(sixWeekMonth.year, sixWeekMonth.month),
      height: height,
    );

    expect(weekCount(tester), 6);
    final bounds = gridBounds(tester);
    expect(bounds.bottom - bounds.top, closeTo(height, 0.5));
  });

  testWidgets('5주짜리 달도 아래 여백 없이 뷰포트를 꽉 채운다', (tester) async {
    const height = 600.0;
    await pump(
      tester,
      DateTime(fiveWeekMonth.year, fiveWeekMonth.month),
      height: height,
    );

    expect(weekCount(tester), 5);
    final bounds = gridBounds(tester);
    expect(bounds.bottom - bounds.top, closeTo(height, 0.5));
  });

  testWidgets('4주짜리 달도 뷰포트를 꽉 채운다', (tester) async {
    const height = 600.0;
    await pump(
      tester,
      DateTime(fourWeekMonth.year, fourWeekMonth.month),
      height: height,
    );

    expect(weekCount(tester), 4);
    final bounds = gridBounds(tester);
    expect(bounds.bottom - bounds.top, closeTo(height, 0.5));
  });

  testWidgets('주 수가 적을수록 셀이 더 높아진다', (tester) async {
    const height = 600.0;

    await pump(
      tester,
      DateTime(sixWeekMonth.year, sixWeekMonth.month),
      height: height,
    );
    final sixWeekCell = tester
        .getRect(find.byType(CalendarDayCell).first)
        .height;

    await pump(
      tester,
      DateTime(fourWeekMonth.year, fourWeekMonth.month),
      height: height,
    );
    final fourWeekCell = tester
        .getRect(find.byType(CalendarDayCell).first)
        .height;

    // 같은 높이를 4주가 나눠 가지므로 6주보다 행이 높다.
    expect(fourWeekCell, greaterThan(sixWeekCell));
    expect(fourWeekCell, closeTo(height / 4, 0.5));
    expect(sixWeekCell, closeTo(height / 6, 0.5));
  });

  testWidgets('뷰포트가 너무 짧으면 최소 행 높이(64)를 지키고 스크롤된다', (tester) async {
    // 6주 × 최소 64 = 384 보다 훨씬 짧은 뷰포트.
    const height = 200.0;
    await pump(
      tester,
      DateTime(sixWeekMonth.year, sixWeekMonth.month),
      height: height,
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final cellHeight = tester
        .getRect(find.byType(CalendarDayCell).first)
        .height;
    expect(cellHeight, closeTo(64, 0.5));
  });

  testWidgets('시작 요일을 일요일로 바꿔도 뷰포트를 꽉 채운다', (tester) async {
    const height = 600.0;
    await pump(
      tester,
      DateTime(sixWeekMonth.year, sixWeekMonth.month),
      height: height,
      weekStart: CalendarWeekStart.sunday,
    );

    final bounds = gridBounds(tester);
    expect(bounds.bottom - bounds.top, closeTo(height, 0.5));
    // 행 높이도 그 달의 실제 주 수에 맞춰 나뉜다.
    final cellHeight = tester
        .getRect(find.byType(CalendarDayCell).first)
        .height;
    expect(cellHeight, closeTo(height / weekCount(tester), 0.5));
  });
}
