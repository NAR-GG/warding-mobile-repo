import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/category_tree.dart';
import 'package:warding/model/schedule_filter_options.dart';
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
