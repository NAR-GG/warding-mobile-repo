import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/viewmodel/match_day/match_day_pager_viewmodel.dart';

class MockScheduleRepository extends Mock implements ScheduleRepository {}

void main() {
  late MockScheduleRepository repo;
  final initialDate = DateTime(2026, 8, 7);

  setUp(() {
    repo = MockScheduleRepository();
    when(() => repo.fetchMatchesByDate(
          any(),
          leagues: any(named: 'leagues'),
          teamIds: any(named: 'teamIds'),
        )).thenAnswer((_) async => const []);
  });

  test('초기 상태는 [초기일-1, 초기일, 초기일+1] 3페이지 윈도우로 채워진다', () async {
    final pager = MatchDayPagerViewModel(
      initialDate: initialDate,
      repository: repo,
    );
    await pumpEventQueue();

    expect(pager.dates, [
      DateTime(2026, 8, 6),
      DateTime(2026, 8, 7),
      DateTime(2026, 8, 8),
    ]);
    expect(pager.pages.length, 3);
    expect(pager.pages[1].date, DateTime(2026, 8, 7));

    verify(() => repo.fetchMatchesByDate(
          DateTime(2026, 8, 6),
          leagues: any(named: 'leagues'),
          teamIds: any(named: 'teamIds'),
        )).called(1);
    verify(() => repo.fetchMatchesByDate(
          DateTime(2026, 8, 8),
          leagues: any(named: 'leagues'),
          teamIds: any(named: 'teamIds'),
        )).called(1);
  });

  test('shift(1) 하면 윈도우가 다음 날짜 방향으로 한 칸 밀린다', () async {
    final pager = MatchDayPagerViewModel(
      initialDate: initialDate,
      repository: repo,
    );
    await pumpEventQueue();
    final oldFirstPage = pager.pages.first;

    pager.shift(1);
    await pumpEventQueue();

    expect(pager.dates, [
      DateTime(2026, 8, 7),
      DateTime(2026, 8, 8),
      DateTime(2026, 8, 9),
    ]);
    verify(() => repo.fetchMatchesByDate(
          DateTime(2026, 8, 9),
          leagues: any(named: 'leagues'),
          teamIds: any(named: 'teamIds'),
        )).called(1);
    // 반대쪽 끝(예전 첫 페이지)은 dispose 되어, 값이 바뀌는 호출은 notifyListeners에서
    // "dispose 후 사용" 단언 오류를 던진다 — dispose가 실제로 호출됐음을 보여준다.
    expect(() => oldFirstPage.setSpoilerPreventionEnabled(false),
        throwsFlutterError);
  });

  test('shift(-1) 하면 윈도우가 이전 날짜 방향으로 한 칸 밀린다', () async {
    final pager = MatchDayPagerViewModel(
      initialDate: initialDate,
      repository: repo,
    );
    await pumpEventQueue();

    pager.shift(-1);
    await pumpEventQueue();

    expect(pager.dates, [
      DateTime(2026, 8, 5),
      DateTime(2026, 8, 6),
      DateTime(2026, 8, 7),
    ]);
    verify(() => repo.fetchMatchesByDate(
          DateTime(2026, 8, 5),
          leagues: any(named: 'leagues'),
          teamIds: any(named: 'teamIds'),
        )).called(1);
  });

  test('setSpoilerPreventionEnabled 는 현재 3페이지 전부와 이후 새로 생기는 페이지에 전파된다',
      () async {
    final pager = MatchDayPagerViewModel(
      initialDate: initialDate,
      repository: repo,
    );
    await pumpEventQueue();
    expect(pager.spoilerPreventionEnabled, isTrue);
    expect(pager.pages.every((p) => p.spoilerPreventionEnabled), isTrue);

    pager.setSpoilerPreventionEnabled(false);
    await pumpEventQueue();

    expect(pager.pages.every((p) => p.spoilerPreventionEnabled == false),
        isTrue);

    pager.shift(1);
    await pumpEventQueue();

    // 새로 생긴 페이지도 꺼진 값을 그대로 물려받는다.
    expect(pager.pages.every((p) => p.spoilerPreventionEnabled == false),
        isTrue);
  });
}
