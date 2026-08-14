import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/calendar_week_start.dart';
import 'package:warding/screens/schedule/component/calendar_day_cell.dart';
import 'package:warding/screens/schedule/component/calendar_month_grid.dart';
import 'package:warding/screens/schedule/component/calendar_weekday_header.dart';
import 'package:warding/screens/schedule/component/schedule_calendar_skeleton.dart';

/// 스켈레톤과 실제 그리드는 같은 자리에 번갈아 그려진다. 로딩이 끝나는
/// 순간 줄 수나 칸 높이가 바뀌면 화면이 튀므로, 둘의 레이아웃이 같은지
/// 확인한다.
void main() {
  Future<void> pumpChild(
    WidgetTester tester,
    Widget child, {
    required double height,
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
            child: SizedBox(width: 375, height: height, child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 실제 그리드를 [ScheduleCalendar] 와 같은 뼈대(가로 패딩 + 요일 헤더 +
  /// Expanded 그리드)로 감싼다. 스켈레톤은 이 뼈대를 자기 안에 포함하므로,
  /// 같은 조건으로 맞춰야 공정한 비교가 된다.
  Widget wrapGrid(DateTime month, CalendarWeekStart weekStart) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekdayHeader(scale: 1, weekStart: weekStart),
          Expanded(
            child: CalendarMonthGrid(
              month: month,
              scale: 1,
              weekStart: weekStart,
              matchesOf: (_) => const [],
            ),
          ),
        ],
      ),
    );
  }

  /// 스켈레톤을 띄우고, 요일 헤더 아래 그리드 영역의 행 높이·행 수를 잰다.
  ///
  /// 스켈레톤 칸은 전용 위젯이 아니라 Container 라서, 실제 그리드의
  /// CalendarDayCell 처럼 타입으로 못 찾는다. 대신 그리드 행을 감싼
  /// SizedBox 중 높이가 지정된 것들을 센다.
  ({int rows, double rowHeight, double top, double bottom}) measureSkeleton(
    WidgetTester tester,
  ) {
    // 행 SizedBox 는 height 가 지정되고 자식이 Row 인 것으로 특정된다.
    final rowFinder = find.byWidgetPredicate(
      (w) => w is SizedBox && w.height != null && w.child is Row,
    );
    expect(rowFinder, findsWidgets);
    final rects = rowFinder
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    for (final r in rects) {
      if (r.top < top) top = r.top;
      if (r.bottom > bottom) bottom = r.bottom;
    }
    return (
      rows: rects.length,
      rowHeight: rects.first.height,
      top: top,
      bottom: bottom,
    );
  }

  /// 실제 그리드의 행 수·행 높이·세로 범위를 잰다.
  ({int rows, double rowHeight, double top, double bottom}) measureGrid(
    WidgetTester tester,
  ) {
    final cells = find.byType(CalendarDayCell);
    expect(cells, findsWidgets);
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    for (final e in cells.evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      if (r.top < top) top = r.top;
      if (r.bottom > bottom) bottom = r.bottom;
    }
    return (
      rows: cells.evaluate().length ~/ 7,
      rowHeight: tester.getRect(cells.first).height,
      top: top,
      bottom: bottom,
    );
  }

  // 주 수가 서로 다른 달들 (월요일 시작 기준).
  final months = <String, DateTime>{
    '6주(2026.08)': DateTime(2026, 8),
    '5주(2026.09)': DateTime(2026, 9),
    '4주(2027.02)': DateTime(2027, 2),
  };

  for (final entry in months.entries) {
    testWidgets('${entry.key} — 스켈레톤과 실제 그리드의 행 수·높이가 같다', (tester) async {
      const height = 600.0;
      final month = entry.value;

      await pumpChild(
        tester,
        ScheduleCalendarSkeleton(month: month, scale: 1),
        height: height,
      );
      final skeleton = measureSkeleton(tester);

      await pumpChild(
        tester,
        wrapGrid(month, CalendarWeekStart.monday),
        height: height,
      );
      final grid = measureGrid(tester);

      expect(skeleton.rows, grid.rows);
      expect(skeleton.rowHeight, closeTo(grid.rowHeight, 0.5));
      // 그리드 영역의 시작·끝 위치까지 같아야 로딩 전후로 안 튄다.
      expect(skeleton.top, closeTo(grid.top, 0.5));
      expect(skeleton.bottom, closeTo(grid.bottom, 0.5));
    });
  }

  testWidgets('스켈레톤도 뷰포트를 세로로 꽉 채운다', (tester) async {
    const height = 600.0;
    await pumpChild(
      tester,
      ScheduleCalendarSkeleton(month: DateTime(2026, 9), scale: 1),
      height: height,
    );

    final skeleton = measureSkeleton(tester);
    expect(skeleton.rows, 5);
    expect(
      skeleton.rowHeight * skeleton.rows,
      closeTo(skeleton.bottom - skeleton.top, 0.5),
    );
    // 요일 헤더가 위를 차지하므로 그리드 영역은 그만큼 짧다. 헤더 아래부터
    // 화면 바닥까지는 빈틈없이 채워야 한다.
    expect(
      skeleton.bottom,
      closeTo(tester.getRect(find.byType(Scaffold)).bottom, 0.5),
    );
  });

  testWidgets('시작 요일이 일요일이면 그 기준 주 수로 그린다', (tester) async {
    const height = 600.0;
    // 2026.09 는 월요일 시작이면 5주, 일요일 시작이면 9/1(화)이 앞으로 밀려 6주.
    await pumpChild(
      tester,
      ScheduleCalendarSkeleton(
        month: DateTime(2026, 9),
        scale: 1,
        weekStart: CalendarWeekStart.sunday,
      ),
      height: height,
    );
    final sunday = measureSkeleton(tester);

    await pumpChild(
      tester,
      wrapGrid(DateTime(2026, 9), CalendarWeekStart.sunday),
      height: height,
    );
    final grid = measureGrid(tester);

    expect(sunday.rows, grid.rows);
    expect(sunday.rowHeight, closeTo(grid.rowHeight, 0.5));
  });

  testWidgets('뷰포트가 너무 짧으면 스켈레톤도 최소 행 높이를 지키고 스크롤된다', (tester) async {
    // 6주 × 최소 64 = 384 보다 훨씬 짧은 뷰포트.
    await pumpChild(
      tester,
      ScheduleCalendarSkeleton(month: DateTime(2026, 8), scale: 1),
      height: 200,
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final skeleton = measureSkeleton(tester);
    expect(skeleton.rowHeight, closeTo(CalendarMonthGrid.minRowHeight, 0.5));
  });
}
