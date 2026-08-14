import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/schedule/component/calendar_month_label.dart';
import 'package:warding/screens/schedule/component/schedule_calendar.dart';
import 'package:warding/screens/schedule/component/schedule_header.dart';

/// 부모(ScheduleScreen)와 같은 방식으로 캘린더를 감싼다 — onMonthShift 로
/// 올라온 이동량을 month 에 반영해 다시 내려준다.
class _Host extends StatefulWidget {
  const _Host({required this.initialMonth, required this.progress});

  final DateTime initialMonth;
  final ValueNotifier<CalendarScrollProgress> progress;

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
            scrollProgress: widget.progress,
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
  late ValueNotifier<CalendarScrollProgress> progress;

  setUp(() {
    progress = ValueNotifier(
      CalendarScrollProgress(month: DateTime(2026, 8), page: 0),
    );
  });

  tearDown(() => progress.dispose());

  Future<_HostState> pump(WidgetTester tester, DateTime month) async {
    await tester.pumpWidget(_Host(initialMonth: month, progress: progress));
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

  testWidgets('스와이프가 끝나면 진행률이 새 달 기준 0 으로 정착한다', (tester) async {
    await pump(tester, DateTime(2026, 8));

    await swipe(tester, forward: true);

    expect(progress.value.month, DateTime(2026, 9));
    expect(progress.value.page, 0);
  });

  testWidgets('드래그 중에는 진행률이 손가락을 따라 0~1 사이로 움직인다', (tester) async {
    await pump(tester, DateTime(2026, 8));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    // 페이지 폭(375)의 1/4 쯤 왼쪽으로. 절반을 넘기면 PageView 가 그 시점에
    // 페이지 인덱스를 바꿔 버려 '중간에 걸친 상태'가 아니게 된다.
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();

    // 기준 달은 그대로인 채, 진행률만 손가락을 따라 중간값이어야 한다.
    expect(progress.value.month, DateTime(2026, 8));
    expect(progress.value.page, greaterThan(0.1));
    expect(progress.value.page, lessThan(0.5));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('외부에서 한 칸 옆 달로 바꾸면 진행률이 그 달 기준으로 정착한다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    // 날짜 피커에서 9월을 고른 상황.
    host.setMonth(DateTime(2026, 9));
    await tester.pumpAndSettle();

    expect(progress.value.month, DateTime(2026, 9));
    expect(progress.value.page, 0);
    // 외부 변경이므로 onMonthShift 는 울리지 않아야 한다.
    expect(host.shifts, isEmpty);
  });

  testWidgets('외부에서 먼 달로 점프해도 진행률이 그 달 기준으로 정착한다', (tester) async {
    final host = await pump(tester, DateTime(2026, 8));

    host.setMonth(DateTime(2027, 3));
    await tester.pumpAndSettle();

    expect(progress.value.month, DateTime(2027, 3));
    expect(progress.value.page, 0);
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
              scrollProgress: progress,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await swipe(tester, forward: true);

    expect(progress.value.month, DateTime(2026, 8));
    expect(progress.value.page, 0);
  });

  _integrationTests();
}

/// 캘린더와 헤더 월 라벨을 실제 화면처럼 함께 띄우고 스와이프한다.
/// 라벨이 매 프레임 다시 그려지므로, 레이아웃이 불안정하면 여기서 터진다.
class _HostWithLabel extends StatefulWidget {
  const _HostWithLabel();

  @override
  State<_HostWithLabel> createState() => _HostWithLabelState();
}

class _HostWithLabelState extends State<_HostWithLabel> {
  final ValueNotifier<CalendarScrollProgress> progress = ValueNotifier(
    CalendarScrollProgress(month: DateTime(2026, 8), page: 0),
  );
  DateTime month = DateTime(2026, 8);

  @override
  void dispose() {
    progress.dispose();
    super.dispose();
  }

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
        body: Column(
          children: [
            ScheduleHeader(
              monthLabel: '2026.08',
              monthLabelWidget: ValueListenableBuilder(
                valueListenable: progress,
                builder: (context, value, _) =>
                    CalendarMonthLabel(progress: value, scale: 1),
              ),
            ),
            Expanded(
              child: ScheduleCalendar(
                month: month,
                matchesByDay: const {},
                scrollProgress: progress,
                onMonthShift: (delta) => setState(
                  () => month = DateTime(month.year, month.month + delta),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _integrationTests() {
  testWidgets('헤더 라벨과 함께 스와이프해도 레이아웃 예외가 없다', (tester) async {
    await tester.pumpWidget(const _HostWithLabel());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 드래그를 여러 프레임에 걸쳐 천천히 — 중간 진행률이 계속 그려진다.
    // 페이지 폭(375)을 확실히 넘겨 다음 달에 정착시킨다.
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

    // 넘어간 뒤 라벨이 새 달을 보여준다.
    expect(find.text('2026.09'), findsOneWidget);
  });

  testWidgets('여러 달을 연속으로 넘겨도 예외 없이 라벨이 따라온다', (tester) async {
    await tester.pumpWidget(const _HostWithLabel());
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    expect(find.text('2026.11'), findsOneWidget);
  });
}
