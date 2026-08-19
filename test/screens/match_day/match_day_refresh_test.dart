import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/screens/match_day/component/match_day_view.dart';
import 'package:warding/viewmodel/match_day/match_day_viewmodel.dart';

class MockScheduleRepository extends Mock implements ScheduleRepository {}

/// 날짜별 경기 리스트(경기 일정 → 날짜 클릭)의 당겨서 새로고침.
///
/// 목록이 비었을 때도 당길 수 있어야 한다 — 조회 실패로 화면이 비어 있는
/// 순간이 새로고침이 가장 필요한 때인데, 스크롤이 안 생긴다고 막히면
/// 사용자는 화면을 나갔다 들어오는 것 말고 방법이 없다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockScheduleRepository repo;

  ScheduleMatch sample() => ScheduleMatch.fromJson({
        'matchId': 'm-1',
        'matchStatus': 'completed',
        'matchTitle': '12주 차 | GEN vs T1',
        'scheduledTime': '17:00',
        'blueTeam': {'teamName': 'Gen.g', 'teamCode': 'GEN', 'score': 2},
        'redTeam': {'teamName': 'T1', 'teamCode': 'T1', 'score': 0},
      });

  Widget host(MatchDayViewModel vm) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => MatchDayView(
              date: DateTime(2026, 8, 19),
              viewModel: vm,
              spoilerPreventionEnabled: false,
              revealedMatchIds: const {},
              onSpoilerReveal: (_) {},
              scale: 1,
            ),
          ),
        ),
      );

  setUp(() {
    repo = MockScheduleRepository();
  });

  testWidgets('목록을 당기면 다시 조회한다', (tester) async {
    when(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    ).thenAnswer((_) async => [sample()]);

    final vm = MatchDayViewModel(date: DateTime(2026, 8, 19), repository: repo);
    addTearDown(vm.dispose);
    await tester.pumpWidget(host(vm));
    await tester.pumpAndSettle();

    // 진입 시 1회.
    verify(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    ).called(1);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    verify(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    ).called(1);
  });

  testWidgets('조회 실패로 비어 있을 때도 당길 수 있다', (tester) async {
    when(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    ).thenThrow(Exception('network'));

    final vm = MatchDayViewModel(date: DateTime(2026, 8, 19), repository: repo);
    addTearDown(vm.dispose);
    await tester.pumpWidget(host(vm));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byType(RefreshProgressIndicator),
      findsOneWidget,
      reason: '비어 있을 때 막히면 화면을 나갔다 오는 수밖에 없다',
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
