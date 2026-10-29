import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/schedule/component/schedule_week_calendar.dart';

/// 주간 캘린더 — 목록 스크롤을 따라 주가 넘어가고, 좌우로 쓸면 전주/다음주.
///
/// 부모(ScheduleScreen)와 같은 방식으로 감싼다: onWeekShift 로 올라온 이동량을
/// anchorDate 에 반영해 다시 내려준다.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.initialDate});
  final DateTime initialDate;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime anchor = widget.initialDate;
  final List<int> shifts = [];

  void setAnchor(DateTime d) => setState(() => anchor = d);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 375,
          child: ScheduleWeekCalendar(
            anchorDate: anchor,
            matchesOfMonth: (_) => const {},
            // 경기 있는 날 칸에는 탭이 걸린다. 그러면 칸마다 제스처 인식기가
            // 생겨 좌우 스와이프를 가로챌 수 있어, 이 조건까지 포함해야
            // '스와이프가 먹는지'를 제대로 본다.
            onDateTap: (_) {},
            onWeekShift: (delta) {
              shifts.add(delta);
              setState(() => anchor = anchor.add(Duration(days: delta * 7)));
            },
          ),
        ),
      ),
    );
  }
}

void main() {
  /// 2026-10-29 는 목요일. 월요일 시작 기준 그 주는 10/26~11/1.
  final thursday = DateTime(2026, 10, 29);

  Future<_HostState> pump(WidgetTester tester, DateTime date) async {
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(_Host(key: key, initialDate: date));
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('기준 날짜가 속한 주 7칸을 그린다', (tester) async {
    await pump(tester, thursday);

    // 10/26(월) ~ 11/1(일)
    for (final day in [26, 27, 28, 29, 30, 31, 1]) {
      expect(find.text('$day'), findsWidgets, reason: '$day 일 칸이 있어야 한다');
    }
    // 그 주에 없는 날짜는 안 보인다.
    expect(find.text('25'), findsNothing);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('부모가 다음 주 날짜를 내려주면 그 주로 옮겨간다', (tester) async {
    final host = await pump(tester, thursday);

    // 목록을 스크롤해 다음 주 경기에 닿은 상황.
    host.setAnchor(DateTime(2026, 11, 5));
    await tester.pumpAndSettle();

    // 11/2(월) ~ 11/8(일)
    for (final day in [2, 3, 4, 5, 6, 7, 8]) {
      expect(find.text('$day'), findsWidgets, reason: '$day 일 칸이 있어야 한다');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('여러 주를 건너뛰어도 그 주로 정확히 간다', (tester) async {
    final host = await pump(tester, thursday);

    // 한 달 뒤 — 애니메이션 없이 점프하는 경로.
    host.setAnchor(DateTime(2026, 12, 3));
    await tester.pumpAndSettle();

    // 11/30(월) ~ 12/6(일)
    for (final day in [30, 1, 2, 3, 4, 5, 6]) {
      expect(find.text('$day'), findsWidgets, reason: '$day 일 칸이 있어야 한다');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('좌우로 쓸면 전주/다음주로 한 칸씩만 넘어간다', (tester) async {
    final host = await pump(tester, thursday);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(host.shifts, [1], reason: '스와이프 한 번에 한 주만 올라와야 한다');
    // 11/2 ~ 11/8
    expect(find.text('2'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('연달아 주가 바뀌어도 중간에서 멈추지 않는다', (tester) async {
    final host = await pump(tester, thursday);

    // 애니메이션이 끝나기 전에 다음 목적지가 연달아 들어오는 상황
    // (목록을 빠르게 내리면 이렇게 된다).
    host.setAnchor(DateTime(2026, 11, 5));
    await tester.pump(const Duration(milliseconds: 50));
    host.setAnchor(DateTime(2026, 11, 12));
    await tester.pumpAndSettle();

    // 최종 목적지인 11/9 ~ 11/15 주에 안착해야 한다.
    for (final day in [9, 10, 11, 12, 13, 14, 15]) {
      expect(find.text('$day'), findsWidgets, reason: '$day 일 칸이 있어야 한다');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('선택된 날짜가 있어도 부모가 다른 주를 내려주면 따라간다', (tester) async {
    // 화면은 `selectedDate ?? _listAnchorDate ?? now` 로 비출 주를 정하는데,
    // 선택이 남아 있으면 목록을 아무리 스크롤해도 그 주에 붙박인다(날짜를
    // 탭한 뒤 목록을 내려도 캘린더가 안 따라오던 증상). 화면 쪽에서 선택을
    // 놓아 주므로, 위젯은 내려온 anchorDate 를 그대로 따라야 한다.
    final host = await pump(tester, thursday);

    host.setAnchor(DateTime(2026, 11, 5));
    await tester.pumpAndSettle();

    for (final day in [2, 3, 4, 5, 6, 7, 8]) {
      expect(find.text('$day'), findsWidgets, reason: '$day 일 칸이 있어야 한다');
    }
    // 옛 주(10/26~11/1)의 고유 날짜는 더 이상 안 보인다.
    expect(find.text('26'), findsNothing);
    expect(find.text('29'), findsNothing);
  });
}
