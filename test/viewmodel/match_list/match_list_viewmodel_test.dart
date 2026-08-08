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
    when(() => sched.fetchMatches(
          cursor: any(named: 'cursor'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
        )).thenAnswer(
        (_) async => const MatchPage(matches: [], nextCursor: null, hasNext: false));
  });

  test('리그 목록은 맨 앞 전체 + 경기일정 필터 옵션(ALLOWED_LEAGUES)에서 온다', () async {
    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    expect(vm.leagues, ['전체', 'LCK', 'MSI']);
  });

  test('기본 선택 리그는 전체이고 첫 조회에 ALL 을 보낸다', () async {
    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    expect(vm.selectedLeague, '전체');
    final captured = verify(() => sched.fetchMatches(
          cursor: any(named: 'cursor'),
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
          cursor: any(named: 'cursor'),
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
          cursor: any(named: 'cursor'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: captureAny(named: 'seasonYear'),
        )).captured;
    expect(captured, contains(2025));
  });

  test("'오늘 이후'는 from=오늘 을 보내고 첫 페이지가 곧 오늘부터다", () async {
    // sortOrders 가 l10n(GlobalKey) 을 읽으므로 바인딩이 필요하다.
    TestWidgetsFlutterBinding.ensureInitialized();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    ScheduleMatch match(String id, DateTime d) => ScheduleMatch(
          matchId: id,
          scheduledTime: '18:00',
          leagueInfo: 'LCK',
          matchTitle: 'A vs B',
          matchStatus: 'unstarted',
          isSynced: false,
          date: d,
          teamA: const MatchTeam(
              teamName: 'A', teamCode: 'A', teamImageUrl: '', score: 0),
          teamB: const MatchTeam(
              teamName: 'B', teamCode: 'B', teamImageUrl: '', score: 0),
        );
    // from 을 주면 서버가 오늘부터 과거→미래 오름차순으로 내려준다.
    final pages = <String?, MatchPage>{
      null: MatchPage(
        matches: [
          for (var i = 0; i < 3; i++) match('today$i', day),
          for (var i = 0; i < 2; i++) match('soon$i', day.add(const Duration(days: 1))),
        ],
        nextCursor: 'c1',
        hasNext: true,
      ),
    };
    when(() => sched.fetchMatches(
          cursor: any(named: 'cursor'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
          from: any(named: 'from'),
        )).thenAnswer((inv) async =>
        pages[inv.namedArguments[const Symbol('cursor')]] ??
        const MatchPage(matches: [], nextCursor: null, hasNext: false));

    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    vm.selectSortOrder(vm.sortOrders[2]); // '오늘 이후'
    await pumpEventQueue();

    expect(vm.upcomingOnly, isTrue);

    // 오늘 날짜를 from 으로 보낸다.
    final sentFrom = verify(() => sched.fetchMatches(
          cursor: any(named: 'cursor'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
          from: captureAny(named: 'from'),
        )).captured;
    final todayParam = '${day.year}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    expect(sentFrom, contains(todayParam));

    // 서버가 오늘부터 주므로 첫 그룹이 곧 오늘이고, 당겨오는 catch-up 이 없다.
    expect(vm.schedule.first.date, day);
    expect(vm.scheduleAscending, isTrue);
    expect(vm.listReversed, isFalse);
    expect(vm.schedule.any((d) => d.date.isBefore(day)), isFalse);
  });

  test("'오늘 이후'가 아니면 from 을 보내지 않는다", () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    when(() => sched.fetchMatches(
          cursor: any(named: 'cursor'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
          from: any(named: 'from'),
        )).thenAnswer(
        (_) async => const MatchPage(matches: [], nextCursor: null, hasNext: false));

    final vm = MatchListViewModel(categoryRepository: cat, scheduleRepository: sched);
    await pumpEventQueue();

    expect(vm.upcomingOnly, isFalse);
    expect(vm.scheduleAscending, isFalse);
    // 기본 '오래된 순'은 최신→과거로 받아 View 가 뒤집어 그린다.
    expect(vm.listReversed, isTrue);

    final sentFrom = verify(() => sched.fetchMatches(
          cursor: any(named: 'cursor'),
          size: any(named: 'size'),
          league: any(named: 'league'),
          seasonYear: any(named: 'seasonYear'),
          from: captureAny(named: 'from'),
        )).captured;
    expect(sentFrom.every((v) => v == null), isTrue);
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
            cursor: any(named: 'cursor'),
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
  });
}
