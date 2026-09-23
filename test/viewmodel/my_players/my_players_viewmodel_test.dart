import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/viewmodel/my_players/my_players_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';

class _FakeSolo implements SoloRankSource {
  _FakeSolo(this.snap);
  SoloRankSnapshot snap;
  bool fail = false;
  @override
  Future<SoloRankSnapshot> fetch() async {
    if (fail) throw Exception('solo down');
    return snap;
  }
}

const _teams = [
  'T1',
  'GEN',
  'HLE',
  'KT',
  'DK',
  'BFX',
  'NS',
  'DRX',
  'BRO',
  'DNF',
];

PlayerSubscription sub(String name, String teamCode) => PlayerSubscription(
  playerId: name.hashCode,
  playerName: name,
  playerImageUrl: '',
  role: 'MID',
  teamId: teamCode.hashCode,
  teamCode: teamCode,
  teamName: teamCode,
  teamImageUrl: '',
  subscribed: true,
  startEnabled: true,
  endEnabled: true,
);

/// 팀 10개 × 10명 = 100명. 이름은 `{팀}-{번호}`, 몇 명만 실명으로 둔다.
List<PlayerSubscription> hundred() {
  final named = {
    'T1': ['Faker', 'Keria', 'Oner'],
    'GEN': ['Chovy', 'Canyon'],
  };
  return [
    for (final team in _teams)
      for (var i = 0; i < 10; i++)
        sub(
          i < (named[team]?.length ?? 0) ? named[team]![i] : '$team-p$i',
          team,
        ),
  ];
}

HomeLiveSoloPlayer live(String name, String team, int elapsed) =>
    HomeLiveSoloPlayer(
      name: name,
      teamCode: team,
      champion: '아리',
      elapsedSeconds: elapsed,
    );

HomeFinishedSoloPlayer done(String name, String team, int minutesAgo) =>
    HomeFinishedSoloPlayer(
      name: name,
      teamCode: team,
      won: true,
      minutesAgo: minutesAgo,
    );

void main() {
  late MockSubscriptionRepository repo;
  late _FakeSolo solo;

  setUp(() {
    repo = MockSubscriptionRepository();
    when(
      () => repo.fetchSubscribedPlayers(),
    ).thenAnswer((_) async => hundred());
    solo = _FakeSolo(
      SoloRankSnapshot(
        live: [live('Faker', 'T1', 300), live('Chovy', 'GEN', 100)],
        finished: [
          done('Oner', 'T1', 12),
          done('Canyon', 'GEN', 40),
          // 진행 중인데 오늘 끝난 기록도 있는 선수 — liveSolo 에만.
          done('Faker', 'T1', 90),
          // 같은 선수 두 건 — 한 번만.
          done('Oner', 'T1', 200),
        ],
        subscribedTotal: 0,
      ),
    );
  });

  Future<MyPlayersViewModel> build() async {
    final vm = MyPlayersViewModel(subscriptions: repo, soloRank: solo);
    await vm.refresh();
    addTearDown(vm.dispose);
    return vm;
  }

  List<String> names(List<MyPlayerEntry> list) => [
    for (final e in list) e.player.playerName,
  ];

  group('상태 분류', () {
    test('솔랭 중 / 오늘 경기함 / 소식 없음으로 나눈다', () async {
      final vm = await build();
      // 최근에 시작한(경과 짧은) 선수가 먼저.
      expect(names(vm.liveSolo), ['Chovy', 'Faker']);
      expect(names(vm.playedToday), ['Oner', 'Canyon']);
      expect(vm.quiet.length, 96);
      expect(vm.liveSolo.length + vm.playedToday.length + vm.quiet.length, 100);
      expect(
        vm.liveSolo.every((e) => e.status == MyPlayerStatus.liveSolo),
        isTrue,
      );
      expect(vm.liveSolo.first.live?.name, 'Chovy');
      expect(
        vm.playedToday.every((e) => e.status == MyPlayerStatus.playedToday),
        isTrue,
      );
      expect(vm.quiet.every((e) => e.status == MyPlayerStatus.quiet), isTrue);
    });

    test('진행 중이면서 종료 기록도 있는 선수는 liveSolo 에만 나온다', () async {
      final vm = await build();
      expect(names(vm.liveSolo), contains('Faker'));
      expect(names(vm.playedToday), isNot(contains('Faker')));
      expect(names(vm.quiet), isNot(contains('Faker')));
    });

    test('오늘 끝난 기록은 선수당 가장 최근 1건', () async {
      final vm = await build();
      final oner = vm.playedToday.firstWhere(
        (e) => e.player.playerName == 'Oner',
      );
      expect(oner.finished?.minutesAgo, 12);
    });

    test('구독하지 않은 선수의 솔랭 기록은 무시한다', () async {
      solo.snap = SoloRankSnapshot(
        live: [live('Zeus', 'HLE', 50)],
        finished: [done('Ruler', 'HLE', 5)],
        subscribedTotal: 0,
      );
      final vm = await build();
      expect(vm.liveSolo, isEmpty);
      expect(vm.playedToday, isEmpty);
      expect(vm.quiet.length, 100);
    });
  });

  group('필터', () {
    test('검색은 이름 부분일치·대소문자 무시로 세 그룹 모두에 적용된다', () async {
      final vm = await build();
      vm.setQuery('fak');
      expect(names(vm.liveSolo), ['Faker']);
      expect(vm.playedToday, isEmpty);
      expect(vm.quiet, isEmpty);

      vm.setQuery('T1-P');
      expect(vm.liveSolo, isEmpty);
      expect(names(vm.quiet), [
        'T1-p3',
        'T1-p4',
        'T1-p5',
        'T1-p6',
        'T1-p7',
        'T1-p8',
        'T1-p9',
      ]);

      vm.setQuery('  ');
      expect(vm.quiet.length, 96);
    });

    test('팀 필터는 해당 팀만, null 이면 전체', () async {
      final vm = await build();
      vm.setTeamCode('T1');
      expect(vm.teamCode, 'T1');
      expect(names(vm.liveSolo), ['Faker']);
      expect(names(vm.playedToday), ['Oner']);
      expect(vm.quiet.length, 8);
      expect(
        [
          ...vm.liveSolo,
          ...vm.playedToday,
          ...vm.quiet,
        ].every((e) => e.player.teamCode == 'T1'),
        isTrue,
      );

      vm.setTeamCode(null);
      expect(vm.teamCode, isNull);
      expect(vm.liveSolo.length + vm.playedToday.length + vm.quiet.length, 100);
    });

    test('검색과 팀 필터는 함께 적용된다', () async {
      final vm = await build();
      vm.setTeamCode('GEN');
      vm.setQuery('c');
      expect(names(vm.liveSolo), ['Chovy']);
      expect(names(vm.playedToday), ['Canyon']);
      expect(vm.quiet, isEmpty);

      vm.setTeamCode('T1');
      expect(vm.liveSolo, isEmpty);
    });

    test('필터가 바뀌면 알린다', () async {
      final vm = await build();
      var count = 0;
      vm.addListener(() => count++);
      vm.setQuery('fa');
      vm.setQuery('fa'); // 같은 값은 무시
      vm.setTeamCode('T1');
      vm.setTeamCode('T1');
      expect(count, 2);
    });

    test('teamCodes 는 구독 선수 소속팀을 처음 나온 순서대로 한 번씩', () async {
      final vm = await build();
      expect(vm.teamCodes, _teams);
    });
  });

  group('소식 없음 접기', () {
    test('기본은 5명만 보이고 나머지는 숨긴 수로 센다', () async {
      final vm = await build();
      expect(vm.quietExpanded, isFalse);
      expect(vm.quietVisible.length, MyPlayersViewModel.quietVisibleCap);
      expect(MyPlayersViewModel.quietVisibleCap, 5);
      expect(vm.quietHiddenCount, 96 - 5);
    });

    test('toggleQuietExpanded 로 전부 펼치고 다시 접는다', () async {
      final vm = await build();
      vm.toggleQuietExpanded();
      expect(vm.quietExpanded, isTrue);
      expect(vm.quietVisible.length, 96);
      expect(vm.quietHiddenCount, 0);
      vm.toggleQuietExpanded();
      expect(vm.quietVisible.length, 5);
    });

    test('5명 이하면 숨긴 수는 0', () async {
      final vm = await build();
      vm.setTeamCode('GEN');
      vm.setQuery('gen-p');
      expect(vm.quiet.length, 8);
      vm.setQuery('gen-p9');
      expect(vm.quiet.length, 1);
      expect(vm.quietHiddenCount, 0);
      expect(vm.quietVisible.length, 1);
    });
  });

  group('로드 실패·비회원', () {
    test('구독 조회가 실패하면(비회원 포함) 0명 — 에러 상태 없이 빈 목록', () async {
      when(() => repo.fetchSubscribedPlayers()).thenThrow(Exception('no jwt'));
      final vm = await build();
      expect(vm.subscribedTotal, 0);
      expect(vm.liveSolo, isEmpty);
      expect(vm.quiet, isEmpty);
      expect(vm.teamCodes, isEmpty);
    });

    test('솔랭 조회가 실패해도 구독 선수는 소식 없음으로 나온다', () async {
      solo.fail = true;
      final vm = await build();
      expect(vm.subscribedTotal, 100);
      expect(vm.liveSolo, isEmpty);
      expect(vm.quiet.length, 100);
    });

    test('다시 불러오다 실패하면 마지막 값을 유지한다', () async {
      final vm = await build();
      solo.fail = true;
      when(() => repo.fetchSubscribedPlayers()).thenThrow(Exception('down'));
      await vm.refresh();
      expect(vm.subscribedTotal, 100);
      expect(names(vm.liveSolo), ['Chovy', 'Faker']);
    });
  });
}
