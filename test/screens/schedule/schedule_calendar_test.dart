import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/schedule/component/schedule_calendar.dart';

/// 부모(ScheduleScreen)와 같은 방식으로 캘린더를 감싼다 — onMonthShift 로
/// 올라온 이동량을 month 에 반영해 다시 내려준다.
class _Host extends StatefulWidget {
  const _Host({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime month = widget.initialMonth;

  /// onMonthShift 로 올라온 이동량 기록 — 스와이프 한 번에 한 칸만 올라와야 한다.
  final List<int> shifts = [];

  void setMonth(DateTime value) => setState(() => month = value);

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
          height: 600,
          child: ScheduleCalendar(
            month: month,
            matchesByDay: const {},
            onMonthShift: (delta) {
              shifts.add(delta);
              setState(() => month = DateTime(month.year, month.month + delta));
            },
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<_HostState> pump(WidgetTester tester, DateTime month) async {
    await tester.pumpWidget(_Host(initialMonth: month));
    await tester.pumpAndSettle();
    return tester.state<_HostState>(find.byType(_Host));
  }

  /// 왼쪽으로 미는 = 다음 달, 오른쪽 = 이전 달.
  Future<void> swipe(WidgetTester tester, {required bool forward}) async {
    await tester.fling(
      find.byType(PageView),
      Offset(forward ? -300 : 300, 0),
      1000,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('앞으로 스와이프하면 다음 달로 한 칸만 이동한다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    await swipe(tester, forward: true);

    expect(host.shifts, [1]);
    expect(host.month, DateTime(2026, 9));
  });

  testWidgets('왕복 스와이프해도 두 달씩 건너뛰지 않는다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    await swipe(tester, forward: true); // 8월 → 9월
    await swipe(tester, forward: false); // 9월 → 8월
    await swipe(tester, forward: true); // 8월 → 9월

    expect(host.shifts, [1, -1, 1]);
    expect(host.month, DateTime(2026, 9));
  });

  testWidgets('연말을 넘어가면 해가 바뀐다', (tester) async {
    final host = await pump(tester, DateTime(2026, 12));

    await swipe(tester, forward: true);

    expect(host.month, DateTime(2027, 1));
  });

  testWidgets('외부에서 한 칸 옆 달로 바꾸면 애니메이션 후 정착한다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    // 날짜 피커에서 9월을 고른 상황.
    host.setMonth(DateTime(2026, 9));
    await tester.pumpAndSettle();

    expect(host.month, DateTime(2026, 9));
    // 외부 변경이므로 onMonthShift 는 울리지 않아야 한다.
    expect(host.shifts, isEmpty);
  });

  testWidgets('외부에서 먼 달로 점프해도 정착한다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    host.setMonth(DateTime(2027, 3));
    await tester.pumpAndSettle();

    expect(host.month, DateTime(2027, 3));
    expect(host.shifts, isEmpty);
  });

  testWidgets('onMonthShift 가 null 이면 스와이프가 먹지 않는다', (tester) async {
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
          body: SizedBox(
            width: 375,
            height: 600,
            child: ScheduleCalendar(
              month: DateTime(2026, 8),
              matchesByDay: const {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await swipe(tester, forward: true);

    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsWidgets); // 캘린더가 8월 그대로 그려져 있다.
  });

  testWidgets('드래그 도중 예외 없이 여러 프레임을 그린다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: '드래그 $i 프레임에서 예외');
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(host.month, DateTime(2026, 9));
    expect(host.shifts, [1]);
  });

  testWidgets('여러 달을 연속으로 넘겨도 예외 없이 이동한다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    for (var i = 0; i < 3; i++) {
      await swipe(tester, forward: true);
      expect(tester.takeException(), isNull);
    }

    expect(host.month, DateTime(2026, 11));
  });
}
