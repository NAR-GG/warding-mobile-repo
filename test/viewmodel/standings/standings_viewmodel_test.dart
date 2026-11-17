import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:warding/features/schedule/domain/schedule_filter_options.dart';
import 'package:warding/features/standings/domain/repositories/standings_repository.dart';
import 'package:warding/features/standings/domain/standing.dart';
import 'package:warding/features/standings/presentation/viewmodels/standings_viewmodel.dart';

class _MockStandings extends Mock implements StandingsRepository {}

class _MockSchedule extends Mock implements ScheduleRepository {}

StandingsResult _result({
  String league = 'LCK',
  bool supported = true,
  StandingsBracket? bracket,
}) => StandingsResult(
  league: league,
  supported: supported,
  scopeLabel: '정규시즌',
  groups: const [],
  bracket: bracket,
);

ScheduleFilterOptions _options({
  String defaultLeague = 'LCK',
  required List<FilterLeague> leagues,
}) => ScheduleFilterOptions(
  defaultLeague: defaultLeague,
  leagues: leagues,
  teams: const [],
);

/// `alarm` 이 있어야 서버가 리그 메타를 준 것으로 본다(hasLeagueMeta).
FilterLeague _league(String code, {bool? standings, String name = ''}) =>
    FilterLeague(
      code: code,
      name: name,
      standings: standings,
      alarm: true,
    );

void main() {
  late _MockStandings repo;
  late _MockSchedule schedule;
  late StandingsViewModel vm;

  setUp(() {
    repo = _MockStandings();
    schedule = _MockSchedule();
    vm = StandingsViewModel(repository: repo, schedule: schedule);
    // 기본 — 순위표 지원 확인은 통과.
    when(() => repo.fetchStandings(any()))
        .thenAnswer((_) async => Right(_result()));
  });

  void stubOptions(ScheduleFilterOptions options) {
    when(
      () => schedule.fetchFilterOptions(league: any(named: 'league')),
    ).thenAnswer((_) async => Right(options));
  }

  test('생성만으로는 조회하지 않고 기본 칩 하나로 시작한다', () {
    // 폴백 5개를 먼저 그렸다가 서버가 지운 칩이 사라지는 깜빡임을 피한다.
    expect(vm.leagueChips.single.code, 'LCK');
    expect(vm.selectedLeague, 'LCK');
  });

  test('칩 목록·순서는 서버가 정한다 — 앱에서 다시 정렬하지 않는다', () async {
    stubOptions(
      _options(
        leagues: [
          _league('LPL', standings: true, name: 'LPL 리그'),
          _league('LCK', standings: true),
          _league('ALL', standings: true), // ALL 은 칩이 아니다
          _league('LEC'), // standings 가 null 이면 칩 없음
        ],
      ),
    );

    await vm.loadLeagueChips();

    expect(vm.leagueChips.map((c) => c.code).toList(), ['LPL', 'LCK']);
    // 서버 표시명을 쓴다. 비어 있을 때만 코드로 폴백.
    expect(vm.leagueChips.first.label, 'LPL 리그');
    expect(vm.leagueChips[1].label, 'LCK');
  });

  test('서버 메타가 없으면 하드코딩 폴백을 쓴다', () async {
    // alarm 이 전부 null → hasLeagueMeta false
    when(
      () => schedule.fetchFilterOptions(league: any(named: 'league')),
    ).thenAnswer(
      (_) async => Right(
        ScheduleFilterOptions(
          defaultLeague: 'LCK',
          leagues: const [FilterLeague(code: 'LCK', name: 'LCK')],
          teams: const [],
        ),
      ),
    );

    await vm.loadLeagueChips();

    expect(vm.leagueChips.length, 5);
    expect(vm.leagueChips.map((c) => c.code), contains('WORLDS'));
  });

  test('조회 실패하면 폴백 칩을 쓴다', () async {
    when(
      () => schedule.fetchFilterOptions(league: any(named: 'league')),
    ).thenAnswer((_) async => const Left(ServerFailure()));

    await vm.loadLeagueChips();

    expect(vm.leagueChips.length, 5);
  });

  test('등록만 되고 데이터가 없는 리그는 점선(live false)으로 둔다', () async {
    stubOptions(_options(leagues: [_league('DEMACIA_CUP', standings: true)]));
    // supported false + 대진도 없음 → 그릴 게 없다
    when(() => repo.fetchStandings('DEMACIA_CUP'))
        .thenAnswer((_) async => Right(_result(supported: false)));

    await vm.loadLeagueChips();

    expect(vm.leagueChips.single.live, isFalse);
  });

  test('지원 확인이 실패하면 칩을 숨기지 않고 서버 값을 믿는다', () async {
    stubOptions(_options(leagues: [_league('LCK', standings: true)]));
    when(() => repo.fetchStandings('LCK'))
        .thenAnswer((_) async => const Left(ServerFailure()));

    await vm.loadLeagueChips();

    expect(vm.leagueChips.single.live, isTrue);
  });

  test('선택된 리그는 항상 고를 수 있는 칩이어야 한다', () async {
    // 서버가 LCK 를 안 주고 LPL 만 켠 경우 — 선택이 LPL 로 떨어져야 한다.
    stubOptions(
      _options(
        defaultLeague: 'LPL',
        leagues: [_league('LPL', standings: true)],
      ),
    );

    await vm.loadLeagueChips();

    expect(vm.selectedLeague, 'LPL');
  });

  test('사용자가 고른 리그가 아직 live 면 서버 기본값으로 되돌리지 않는다', () async {
    stubOptions(
      _options(
        defaultLeague: 'LCK',
        leagues: [
          _league('LCK', standings: true),
          _league('LPL', standings: true),
        ],
      ),
    );
    await vm.loadLeagueChips();

    vm.selectLeague('LPL');
    expect(vm.selectedLeague, 'LPL');

    // 칩 목록이 다시 와도 사용자 선택을 지킨다.
    await vm.loadLeagueChips();
    expect(vm.selectedLeague, 'LPL');
  });

  test('고를 수 없는 칩은 선택되지 않는다', () async {
    stubOptions(_options(leagues: [_league('LPL', standings: false)]));
    await vm.loadLeagueChips();

    vm.selectLeague('LPL');

    expect(vm.selectedLeague, isNot('LPL'));
  });

  test('표인지 대진인지는 응답이 정한다 — 리그 코드로 분기하지 않는다', () async {
    when(() => repo.fetchStandings('LCK'))
        .thenAnswer((_) async => Right(_result(supported: true)));

    await vm.loadStandings();

    // 대진이 안 실려 오면 리그 테이블이다.
    expect(vm.standingsIsBracket, isFalse);
    expect(vm.standings, isNotNull);
    expect(vm.standingsLoading, isFalse);
  });

  test('리그를 바꾸면 이전 리그의 표를 즉시 버린다', () async {
    stubOptions(
      _options(
        leagues: [
          _league('LCK', standings: true),
          _league('LPL', standings: true),
        ],
      ),
    );
    await vm.loadLeagueChips();
    await vm.loadStandings();
    expect(vm.standings, isNotNull);

    vm.selectLeague('LPL');

    // 안 비우면 새 칩 아래 옛 리그의 표가 남는다.
    expect(vm.standings, isNull);
    expect(vm.standingsLoading, isTrue);
  });

  test('펼치기 토글', () {
    expect(vm.standingsExpanded, isFalse);
    vm.toggleStandingsExpanded();
    expect(vm.standingsExpanded, isTrue);
  });
}
