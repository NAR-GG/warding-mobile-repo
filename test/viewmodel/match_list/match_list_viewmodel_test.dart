import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/category_tree.dart';
import 'package:warding/model/schedule_filter_options.dart';
import 'package:warding/model/schedule_match.dart';
import 'package:warding/repository/category/category_repository.dart';
import 'package:warding/repository/preference/filter_preference_repository.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/viewmodel/match_list/match_list_viewmodel.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockScheduleRepository extends Mock implements ScheduleRepository {}

class MockFilterPreferenceRepository extends Mock
    implements FilterPreferenceRepository {}

void main() {
  late MockCategoryRepository cat;
  late MockScheduleRepository sched;

  ScheduleMatch match(String id, DateTime d) => ScheduleMatch(
        matchId: id,
        scheduledTime: '18:00',
        leagueInfo: 'LCK',
        matchTitle: 'A vs B',
        matchStatus: 'unstarted',
        isSynced: false,
        date: d,
        teamA:
            const MatchTeam(teamName: 'A', teamCode: 'A', teamImageUrl: '', score: 0),
        teamB:
            const MatchTeam(teamName: 'B', teamCode: 'B', teamImageUrl: '', score: 0),
      );

  String dateParam(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  const emptyPage = MatchPage(matches: [], nextCursor: null, hasNext: false);

  setUp(() {
    cat = MockCategoryRepository();
    sched = MockScheduleRepository();

    when(() => sched.fetchFilterOptions(league: any(named: 'league')))
        .thenAnswer((_) async => const ScheduleFilterOptions(
              defaultLeague: 'LCK',
              leagues: [
                // 서버가 맨 앞에 '전체'(ALL)를 포함해 내려준다.
                FilterLeague(code: 'ALL', name: '전체'),
                FilterLeague(code: 'LCK', name: 'LCK'),
                FilterLeague(code: 'MSI', name: 'MSI'),
              ],
              teams: [],
            ));
    when(() => cat.fetchTree(year: any(named: 'year')))
        .thenAnswer((_) async => const CategoryTree(seasons: []));

    // 뷰모델이 만들 수 있는 네 가지 호출 모양(진입=around, 오늘이후 진입=from,
    // 미래 이어받기=cursor+from, 과거 이어받기=before) 을 모두 빈 응답으로
    // 기본 커버해 둔다. 각 테스트는 필요한 모양만 더 구체적으로 재정의한다.
    when(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => emptyPage);
    when(() => sched.fetchMatches(
          from: any(named: 'from'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => emptyPage);
    when(() => sched.fetchMatches(
          cursor: any(named: 'cursor'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
          from: any(named: 'from'),
        )).thenAnswer((_) async => emptyPage);
    when(() => sched.fetchMatches(
          before: any(named: 'before'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => emptyPage);
  });

  test('리그 목록은 맨 앞 전체 + 경기일정 필터 옵션(ALLOWED_LEAGUES)에서 온다', () async {
    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    expect(vm.leagues, ['전체', 'LCK', 'MSI']);
  });

  test('기본 선택 리그는 전체이고 진입 조회에 ALL 을 보낸다', () async {
    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    expect(vm.selectedLeague, '전체');
    final captured = verify(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: captureAny(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).captured;
    expect(captured, contains('ALL'));
  });

  test('경기 조회 시 선택 시즌(연도)을 seasonYear 로 넘긴다', () async {
    MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    final captured = verify(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: captureAny(named: 'seasonYear'),
        )).captured;
    // 기본 시즌은 seasons.last = '2026'.
    expect(captured, contains(2026));
  });

  test('시즌 변경 시 해당 연도를 seasonYear 로 넘긴다', () async {
    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    vm.selectSeason('2025');
    await pumpEventQueue();

    final captured = verify(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: captureAny(named: 'seasonYear'),
        )).captured;
    expect(captured, contains(2025));
  });

  test('진입 시 오늘 날짜를 around 로 보낸다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    expect(vm.upcomingOnly, isFalse);
    final sentAround = verify(() => sched.fetchMatches(
          around: captureAny(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).captured;
    expect(sentAround, contains(dateParam(DateTime.now())));
  });

  test("'오늘 이후'는 from=오늘 을 보내고 첫 페이지가 곧 오늘부터다", () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    // from 을 주면 서버가 오늘부터 과거→미래 오름차순으로 내려준다.
    when(() => sched.fetchMatches(
          from: any(named: 'from'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => MatchPage(
          matches: [
            for (var i = 0; i < 3; i++) match('today$i', day),
            for (var i = 0; i < 2; i++)
              match('soon$i', day.add(const Duration(days: 1))),
          ],
          nextCursor: 'c1',
          hasNext: true,
        ));

    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    vm.selectSortOrder(vm.sortOrders[2]); // '오늘 이후'
    await pumpEventQueue();

    expect(vm.upcomingOnly, isTrue);

    // 오늘 날짜를 from 으로 보낸다.
    final sentFrom = verify(() => sched.fetchMatches(
          from: captureAny(named: 'from'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).captured;
    expect(sentFrom, contains(dateParam(day)));

    // 서버가 오늘부터 주므로 첫 그룹이 곧 오늘이고, 당겨오는 catch-up 이 없다.
    expect(vm.schedule.first.date, day);
    expect(vm.scheduleAscending, isTrue);
    expect(vm.schedule.any((d) => d.date.isBefore(day)), isFalse);
    // '오늘 이후'는 과거를 보여주지 않는다.
    expect(vm.hasPrev, isFalse);
  });

  test('around 응답은 과거→미래 순 그대로 오래된 순 화면에 담긴다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    when(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => MatchPage(
          matches: [
            for (var i = -2; i <= 2; i++)
              match('d$i', today.add(Duration(days: i))),
          ],
          nextCursor: 'next',
          hasNext: true,
          prevCursor: 'prev',
          hasPrev: true,
        ));

    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    // 기본은 '오래된 순'(ascending) → 받은 순서 그대로.
    expect(vm.scheduleAscending, isTrue);
    expect(vm.schedule.first.date, today.subtract(const Duration(days: 2)));
    expect(vm.schedule.last.date, today.add(const Duration(days: 2)));
    expect(vm.hasPrev, isTrue);
    expect(vm.hasMore, isTrue);
  });

  test('최근순은 around 응답을 뒤집어 담는다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    when(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => MatchPage(
          matches: [
            for (var i = -2; i <= 2; i++)
              match('d$i', today.add(Duration(days: i))),
          ],
          nextCursor: 'next',
          hasNext: true,
          prevCursor: 'prev',
          hasPrev: true,
        ));

    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    vm.selectSortOrder(vm.sortOrders[0]); // '최근순'
    await pumpEventQueue();

    expect(vm.scheduleAscending, isFalse);
    expect(vm.schedule.first.date, today.add(const Duration(days: 2)));
    expect(vm.schedule.last.date, today.subtract(const Duration(days: 2)));
    // 최근순에서 아래쪽(과거)을 더 받을 수 있어야 hasMore, 위쪽(미래)을
    // 더 받을 수 있어야 hasPrev.
    expect(vm.hasMore, isTrue);
    expect(vm.hasPrev, isTrue);
  });

  test('아래로 스크롤(최근순) 하면 과거를 before 로 받아 뒤집어 append 한다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    when(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => MatchPage(
          matches: [
            for (var i = -2; i <= 2; i++)
              match('d$i', today.add(Duration(days: i))),
          ],
          nextCursor: 'next',
          hasNext: true,
          prevCursor: 'prev1',
          hasPrev: true,
        ));

    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();
    vm.selectSortOrder(vm.sortOrders[0]); // '최근순'
    await pumpEventQueue();

    when(() => sched.fetchMatches(
          before: 'prev1',
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => MatchPage(
          matches: [
            match('p1', today.subtract(const Duration(days: 4))),
            match('p2', today.subtract(const Duration(days: 3))),
          ],
          nextCursor: null,
          hasNext: false,
          prevCursor: null,
          hasPrev: false,
        ));

    // 최근순에서 화면 '아래쪽 끝' 트리거 = loadMoreMatches, 더 과거를 받아야 한다.
    await vm.loadMoreMatches();
    await pumpEventQueue();

    expect(vm.schedule.first.date, today.add(const Duration(days: 2)));
    expect(vm.schedule.last.date, today.subtract(const Duration(days: 4)));
    expect(vm.hasMore, isFalse, reason: '더 없으면 다시 요청하지 않는다');
  });

  test('위로 스크롤 하면 before 로 과거를 이어받아 맨 앞에 붙인다(오래된 순)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    when(() => sched.fetchMatches(
          around: any(named: 'around'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => MatchPage(
          matches: [
            for (var i = 0; i <= 4; i++) match('d$i', today.add(Duration(days: i))),
          ],
          nextCursor: null,
          hasNext: false,
          prevCursor: 'prev1',
          hasPrev: true,
        ));

    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();
    final beforeCount = vm.schedule.length;

    when(() => sched.fetchMatches(
          before: 'prev1',
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer((_) async => MatchPage(
          matches: [
            match('2026-08-01', DateTime(2026, 8, 1)),
            match('2026-08-02', DateTime(2026, 8, 2)),
          ],
          nextCursor: null,
          hasNext: false,
          prevCursor: null,
          hasPrev: false,
        ));

    await vm.loadPreviousMatches();
    await pumpEventQueue();

    expect(vm.schedule.length, greaterThan(beforeCount));
    expect(vm.schedule.first.date.month, 8);
    expect(vm.schedule.first.date.day, 1, reason: '과거가 맨 앞에 와야 한다');
    expect(vm.hasPrev, isFalse, reason: '더 없으면 다시 요청하지 않는다');
  });

  test('hasPrev 가 false 면 과거 요청을 보내지 않는다', () async {
    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    expect(vm.hasPrev, isFalse);

    await vm.loadPreviousMatches();
    await pumpEventQueue();

    verifyNever(() => sched.fetchMatches(
          before: any(named: 'before'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        ));
  });

  group('필터 저장·복원', () {
    late MockFilterPreferenceRepository prefs;

    setUp(() {
      prefs = MockFilterPreferenceRepository();
      when(() => prefs.save(any(), any())).thenAnswer((_) async {});
    });

    MatchListViewModel buildVm() => MatchListViewModel(
          categoryRepository: cat,
          scheduleRepository: sched,
          filterPreferences: prefs,
        );

    test('저장된 리그를 복원해 첫 조회에 반영한다', () async {
      when(() => prefs.load(FilterPreferenceRepository.matchListKey))
          .thenAnswer((_) async => {
                'season': '2026',
                'league': 'LCK',
                'teams': ['전체'],
              });

      final vm = buildVm();
      await pumpEventQueue();

      expect(vm.selectedLeague, 'LCK');
      final captured = verify(() => sched.fetchMatches(
            around: any(named: 'around'),
            size: any(named: 'size'),
            league: captureAny(named: 'league'),
            seasonYear: any(named: 'seasonYear'),
          )).captured;
      expect(captured, contains('LCK'));
    });

    test('저장된 리그가 현재 목록에 없으면 전체로 폴백한다', () async {
      when(() => prefs.load(FilterPreferenceRepository.matchListKey))
          .thenAnswer((_) async => {'league': 'LJL'});

      final vm = buildVm();
      await pumpEventQueue();

      expect(vm.selectedLeague, '전체');
    });

    test('리그 변경 시 필터를 저장한다', () async {
      when(() => prefs.load(FilterPreferenceRepository.matchListKey))
          .thenAnswer((_) async => null);

      final vm = buildVm();
      await pumpEventQueue();

      vm.selectLeague('LCK');
      await pumpEventQueue();

      final saved = verify(() =>
              prefs.save(FilterPreferenceRepository.matchListKey, captureAny()))
          .captured
          .last as Map<String, dynamic>;
      expect(saved['league'], 'LCK');
    });

    test('정렬 변경 시 저장하고, 다음 실행에 복원한다', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      when(() => prefs.load(FilterPreferenceRepository.matchListKey))
          .thenAnswer((_) async => null);

      final vm = buildVm();
      await pumpEventQueue();

      vm.selectSortOrder(vm.sortOrders[2]); // '오늘 이후'
      await pumpEventQueue();

      final saved = verify(() =>
              prefs.save(FilterPreferenceRepository.matchListKey, captureAny()))
          .captured
          .last as Map<String, dynamic>;
      expect(saved['sortOrder'], 2);

      // 저장된 값으로 새로 띄우면 '오늘 이후'가 그대로 살아 있어야 한다.
      when(() => prefs.load(FilterPreferenceRepository.matchListKey))
          .thenAnswer((_) async => saved);

      final restored = buildVm();
      await pumpEventQueue();

      expect(restored.upcomingOnly, isTrue);
      expect(restored.scheduleAscending, isTrue);
    });

    test('저장된 정렬 인덱스가 범위를 벗어나면 기본값을 쓴다', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      when(() => prefs.load(FilterPreferenceRepository.matchListKey))
          .thenAnswer((_) async => {'sortOrder': 99});

      final vm = buildVm();
      await pumpEventQueue();

      expect(vm.upcomingOnly, isFalse);
      expect(vm.sortOrder, vm.sortOrders[1]); // 기본 '오래된 순'
    });
  });
}
