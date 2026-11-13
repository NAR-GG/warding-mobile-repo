import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/core/error/failure.dart';
import 'package:warding/domain/schedule_match.dart';
import 'package:warding/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:warding/features/schedule/presentation/viewmodels/today_matches_viewmodel.dart';

class _MockRepo extends Mock implements ScheduleRepository {}

ScheduleMatch _match(String id, String status) => ScheduleMatch.fromJson({
  'matchId': id,
  'scheduledTime': '18:00',
  'leagueName': 'LCK',
  'matchTitle': '정규시즌',
  'matchStatus': status,
  'isSynced': true,
  'blueTeam': {'teamName': 'T1', 'teamCode': 'T1', 'teamImageUrl': ''},
  'redTeam': {'teamName': 'Gen.G', 'teamCode': 'GEN', 'teamImageUrl': ''},
});

void main() {
  late _MockRepo repo;
  late TodayMatchesViewModel vm;

  void stub(List<ScheduleMatch> matches) {
    when(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    ).thenAnswer((_) async => Right(matches));
  }

  setUp(() {
    repo = _MockRepo();
    vm = TodayMatchesViewModel(repository: repo);
  });

  test('생성만으로는 조회하지 않는다', () {
    verifyNever(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    );
    expect(vm.loading, isTrue);
    expect(vm.sorted, isEmpty);
  });

  test('진행 중인 경기를 앞으로 정렬한다', () async {
    stub([
      _match('예정', 'unstarted'),
      _match('진행', 'inProgress'),
      _match('종료', 'completed'),
    ]);

    await vm.load();

    expect(vm.sorted.first.matchId, '진행');
    expect(vm.loading, isFalse);
    // 진행 중이 아닌 것들끼리는 서버 순서를 유지한다.
    expect(vm.sorted.map((m) => m.matchId).toList(), ['진행', '예정', '종료']);
  });

  test('전체 리그를 요청한다', () async {
    stub([]);

    await vm.load();

    verify(
      () => repo.fetchMatchesByDate(any(), leagues: const ['ALL']),
    ).called(1);
  });

  test('실패하면 마지막 값을 유지하고 로딩만 끝낸다', () async {
    stub([_match('m1', 'inProgress')]);
    await vm.load();

    when(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure()));
    await vm.load();

    expect(vm.sorted.single.matchId, 'm1');
    expect(vm.loading, isFalse);
  });

  test('느린 응답이 새 응답을 덮지 않는다', () async {
    // 첫 호출은 늦게, 두 번째는 즉시 — 세대 카운터가 첫 응답을 버려야 한다.
    var call = 0;
    when(
      () => repo.fetchMatchesByDate(
        any(),
        leagues: any(named: 'leagues'),
        teamIds: any(named: 'teamIds'),
      ),
    ).thenAnswer((_) async {
      call++;
      if (call == 1) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Right([_match('느림', 'inProgress')]);
      }
      return Right([_match('빠름', 'inProgress')]);
    });

    final slow = vm.load();
    await vm.load();
    await slow;

    expect(vm.sorted.single.matchId, '빠름');
  });
}
