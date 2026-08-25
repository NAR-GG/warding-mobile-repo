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

  // 달력에 걸치는 주 수가 서로 다른 달들. 월요일 시작 기준.
  // - 2026.08: 8/1 이 토요일 → 6주에 걸친다
  // - 2026.09: 9/1 이 화요일 → 5주
  // - 2027.02: 2/1 이 월요일, 28일 → 정확히 4주
  const sixWeekMonth = (year: 2026, month: 8);
  const fiveWeekMonth = (year: 2026, month: 9);
  const fourWeekMonth = (year: 2027, month: 2);

  testWidgets('어느 달이든 6행으로 뷰포트를 꽉 채운다', (tester) async {
    const height = 600.0;

    for (final month in [sixWeekMonth, fiveWeekMonth, fourWeekMonth]) {
      await pump(tester, DateTime(month.year, month.month), height: height);

      expect(weekCount(tester), 6, reason: '$month 의 행 수');
      final bounds = gridBounds(tester);
      expect(
        bounds.bottom - bounds.top,
        closeTo(height, 0.5),
        reason: '$month 의 그리드 높이',
      );
    }
  });

  testWidgets('달이 바뀌어도 행 높이가 같다', (tester) async {
    const height = 600.0;

    // 스와이프 중에는 두 달 페이지가 나란히 보인다. 행 높이가 다르면 가로
    // 구분선이 서로 어긋나 전환이 깨져 보이므로, 어느 달이든 같아야 한다.
    final heights = <double>[];
    for (final month in [sixWeekMonth, fiveWeekMonth, fourWeekMonth]) {
      await pump(tester, DateTime(month.year, month.month), height: height);
      heights.add(tester.getRect(find.byType(CalendarDayCell).first).height);
    }

    for (final cellHeight in heights) {
      expect(cellHeight, closeTo(height / 6, 0.5));
    }
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
    expect(weekCount(tester), 6);
    final cellHeight = tester
        .getRect(find.byType(CalendarDayCell).first)
        .height;
    expect(cellHeight, closeTo(height / 6, 0.5));
  });
}
