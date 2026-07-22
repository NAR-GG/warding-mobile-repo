import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/schedule_filter_options.dart';
import 'package:warding/repository/schedule/schedule_repository.dart';
import 'package:warding/viewmodel/schedule/filter_viewmodel.dart';

class MockScheduleRepository extends Mock implements ScheduleRepository {}

const _options = ScheduleFilterOptions(
  defaultLeague: 'LCK',
  leagues: [
    FilterLeague(code: 'ALL', name: '전체'),
    FilterLeague(code: 'LCK', name: 'LCK'),
    FilterLeague(code: 'LEC', name: 'LEC'),
  ],
  teams: [
    FilterTeam(teamId: 1, teamName: 'T1', teamCode: 'T1', teamImageUrl: ''),
    FilterTeam(teamId: 2, teamName: 'GenG', teamCode: 'GEN', teamImageUrl: ''),
  ],
);

void main() {
  late MockScheduleRepository repo;

  setUp(() {
    repo = MockScheduleRepository();
    when(() => repo.fetchFilterOptions(league: any(named: 'league')))
        .thenAnswer((_) async => _options);
  });

  test('초기 상태는 전체 — 리그·팀 옵션 첫 항목이 선택돼 있다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    expect(vm.leagueOptions.first.name, '전체');
    expect(vm.leagueOptions.first.selected, isTrue);
    expect(vm.teamOptions.first.name, '전체');
    expect(vm.teamOptions.first.selected, isTrue);
    expect(vm.selectedLeagueSummary, isNull);
    expect(vm.selectedTeamSummary, isNull);
    expect(vm.isApplyEnabled, isFalse);
  });

  test('리그를 토글하면 선택되고, 결과에 담긴다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleLeague('LCK');
    await pumpEventQueue();

    expect(vm.result.leagues, ['LCK']);
    expect(vm.selectedLeagueSummary, 'LCK');
    expect(vm.isApplyEnabled, isTrue);
  });

  test('리그를 여러 개 선택할 수 있다 — 선택된 항목이 앞으로 정렬된다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleLeague('LCK');
    vm.toggleLeague('LEC');
    await pumpEventQueue();

    expect(vm.result.leagues.toSet(), {'LCK', 'LEC'});
    final selected = vm.leagueOptions.where((o) => o.selected).map((o) => o.name).toSet();
    expect(selected, {'LCK', 'LEC'});
    // 선택된 항목이 옵션 목록 앞쪽에 온다.
    expect(vm.leagueOptions.take(2).every((o) => o.selected), isTrue);
  });

  test('특정 리그를 선택하면 전체 선택이 해제된다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleLeague('LCK');
    await pumpEventQueue();

    final allOption = vm.leagueOptions.firstWhere((o) => o.name == '전체');
    expect(allOption.selected, isFalse);
  });

  test('선택된 리그를 전부 해제하면 다시 전체로 돌아간다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleLeague('LCK');
    await pumpEventQueue();
    vm.toggleLeague('LCK'); // 마지막 선택 해제
    await pumpEventQueue();

    expect(vm.result.leagues, ['ALL']);
    expect(vm.leagueOptions.firstWhere((o) => o.name == '전체').selected, isTrue);
  });

  test('전체를 다시 탭하면 다른 선택이 모두 지워진다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleLeague('LCK');
    vm.toggleLeague('LEC');
    await pumpEventQueue();
    vm.toggleLeague('전체');
    await pumpEventQueue();

    expect(vm.result.leagues, ['ALL']);
  });

  test('리그 선택이 바뀌면 팀 선택이 초기화된다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleTeam('T1');
    await pumpEventQueue();
    expect(vm.result.teamIds, [1]);

    vm.toggleLeague('LCK');
    await pumpEventQueue();

    expect(vm.result.teamIds, isEmpty);
  });

  test('팀을 여러 개 선택할 수 있다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleTeam('T1');
    vm.toggleTeam('GenG');
    await pumpEventQueue();

    expect(vm.result.teamIds.toSet(), {1, 2});
  });

  test('리그가 정확히 하나 선택되면 그 리그로 팀 옵션을 다시 받아온다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleLeague('LCK');
    await pumpEventQueue();

    verify(() => repo.fetchFilterOptions(league: 'LCK')).called(1);
  });

  test('리그를 두 개 이상 선택하면 선택된 리그들을 각각 조회해 팀 목록을 합친다', () async {
    final vm = FilterViewModel(repository: repo);
    await pumpEventQueue();

    vm.toggleLeague('LCK');
    vm.toggleLeague('LEC');
    await pumpEventQueue();

    verify(() => repo.fetchFilterOptions(league: 'LCK'))
        .called(greaterThanOrEqualTo(1));
    verify(() => repo.fetchFilterOptions(league: 'LEC')).called(1);
    expect(vm.teamOptions.map((o) => o.name).toSet(), {'전체', 'T1', 'GenG'});
  });

  test('초기화하면 리그·팀 모두 전체로 되돌아가고 조회 버튼이 활성화된다', () async {
    final vm = FilterViewModel(
      initialLeagues: const ['LCK'],
      initialTeamIds: const [1],
      repository: repo,
    );
    await pumpEventQueue();
    expect(vm.isApplyEnabled, isFalse);

    vm.reset();
    await pumpEventQueue();

    expect(vm.result.leagues, ['ALL']);
    expect(vm.result.teamIds, isEmpty);
    expect(vm.result.resetMonth, isTrue);
    expect(vm.isApplyEnabled, isTrue);
  });
}
