import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/calendar_week_start.dart';
import 'package:warding/screens/schedule/component/calendar_day_cell.dart';
import 'package:warding/screens/schedule/component/calendar_weekday_header.dart';
import 'package:warding/screens/schedule/component/schedule_calendar.dart';
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

  /// 실제 그리드를 [ScheduleCalendar] 와 같은 뼈대로 감싼다.
  ///
  /// 캘린더는 아래 경기 리스트와 세로를 나눠 쓰게 되면서 **자기 행 수만큼만**
  /// 차지한다(`SizedBox(height: monthRowHeight * weeks)`). 예전처럼
  /// `Expanded` 로 감싸면 뷰포트를 꽉 채워서, 스켈레톤(고정 높이)과 비교하는
  /// 의미가 없어진다.
  Widget wrapGrid(DateTime month, CalendarWeekStart weekStart) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekdayHeader(scale: 1, weekStart: weekStart),
          SizedBox(
            height:
                ScheduleCalendar.monthRowHeight * CalendarMonthGrid.gridWeeks,
            child: CalendarMonthGrid(
              month: month,
              scale: 1,
              weekStart: weekStart,
              minRowHeightOverride: ScheduleCalendar.monthRowHeight,
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

  testWidgets('스켈레톤은 자기 행 수만큼만 차지한다', (tester) async {
    const height = 600.0;
    await pumpChild(
      tester,
      ScheduleCalendarSkeleton(month: DateTime(2026, 9), scale: 1),
      height: height,
    );

    final skeleton = measureSkeleton(tester);
    // 그리드와 같은 고정 행 수 — 달마다 달라지지 않는다.
    expect(skeleton.rows, 6);
    expect(
      skeleton.rowHeight * skeleton.rows,
      closeTo(skeleton.bottom - skeleton.top, 0.5),
    );
    // 예전엔 뷰포트를 꽉 채웠다. 지금은 아래 경기 리스트와 세로를 나눠 쓰므로
    // 행 수만큼만 차지하고 남는 공간은 목록에 넘긴다 — 실제 캘린더와 같은 규칙.
    expect(
      skeleton.rowHeight,
      closeTo(ScheduleCalendar.monthRowHeight, 0.5),
    );
    expect(
      skeleton.bottom,
      lessThan(tester.getRect(find.byType(Scaffold)).bottom),
      reason: '뷰포트를 다 쓰지 않고 아래를 목록에 남겨야 한다',
    );
  });

  testWidgets('시작 요일이 일요일이어도 그리드와 같은 행 수로 그린다', (tester) async {
    const height = 600.0;
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

  testWidgets('짧은 뷰포트에서도 행 높이를 지킨다', (tester) async {
    // 캘린더는 이제 아래 목록과 세로를 나눠 쓰느라 **자기 행 수만큼** 고정
    // 높이를 차지한다. 부모가 그보다 짧아도 칸을 찌그러뜨리지 않는다 —
    // 찌그러지면 로딩이 끝나는 순간 칸이 튀어 목록이 밀린다.
    await pumpChild(
      tester,
      ScheduleCalendarSkeleton(month: DateTime(2026, 8), scale: 1),
      height: 200,
    );

    final skeleton = measureSkeleton(tester);
    expect(
      skeleton.rowHeight,
      closeTo(ScheduleCalendar.monthRowHeight, 0.5),
      reason: '뷰포트가 짧아도 실제 그리드와 같은 행 높이를 쓴다',
    );
  });
}
