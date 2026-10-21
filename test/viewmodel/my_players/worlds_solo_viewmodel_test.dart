import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/viewmodel/my_players/my_players_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';

class _FakeWorlds implements WorldsSoloSource {
  _FakeWorlds(this.snap);
  final WorldsSoloSnapshot snap;
  @override
  Future<WorldsSoloSnapshot> fetch() async => snap;
}

PlayerSubscription _player(
  int id,
  String name,
  String team, {
  bool subscribed = false,
}) => PlayerSubscription(
  playerId: id,
  playerName: name,
  playerImageUrl: '',
  role: 'MID',
  teamId: 0,
  teamCode: team,
  teamName: team,
  teamImageUrl: '',
  subscribed: subscribed,
  startEnabled: true,
  endEnabled: false,
);

void main() {
  late MockSubscriptionRepository repo;

  final roster = WorldsSoloSnapshot(
    players: [
      _player(1, 'Faker', 'T1', subscribed: true),
      _player(2, 'Canyon', 'GEN'),
      _player(3, 'Zeus', 'HLE'),
    ],
    solo: const SoloRankSnapshot(
      live: [
        HomeLiveSoloPlayer(
          name: 'Canyon',
          teamCode: 'GEN',
          champion: '키아나',
          elapsedSeconds: 725,
          platform: 'NA1',
        ),
      ],
      finished: [
        HomeFinishedSoloPlayer(
          name: 'Faker',
          teamCode: 'T1',
          won: true,
          minutesAgo: 12,
        ),
      ],
    ),
  );

  setUp(() {
    repo = MockSubscriptionRepository();
    when(() => repo.subscribePlayer(any())).thenAnswer(
      (inv) async => _player(inv.positionalArguments.first as int, '', ''),
    );
    when(() => repo.unsubscribePlayer(any())).thenAnswer((_) async {});
    when(
      () => repo.updatePlayerAlarm(
        any(),
        startEnabled: any(named: 'startEnabled'),
        endEnabled: any(named: 'endEnabled'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<MyPlayersViewModel> build() async {
    final vm = MyPlayersViewModel(
      subscriptions: repo,
      worlds: _FakeWorlds(roster),
    );
    await vm.refresh();
    addTearDown(vm.dispose);
    return vm;
  }

  List<String> names(List<MyPlayerEntry> list) => [
    for (final e in list) e.player.playerName,
  ];

  test('명단 전체를 구독과 무관하게 솔랭 중 / 오늘 기록 / 없음으로 나눈다', () async {
    final vm = await build();
    expect(vm.isWorlds, isTrue);
    expect(vm.subscribedTotal, 3);
    expect(vm.subscribedInRoster, 1);
    expect(names(vm.liveSolo), ['Canyon']);
    expect(names(vm.playedToday), ['Faker']);
    expect(names(vm.quiet), ['Zeus']);
    verifyNever(() => repo.fetchSubscribedPlayers());
  });

  test('"구독 선수" 탭은 구독한 선수만 남긴다', () async {
    final vm = await build();
    vm.setSubscribedOnly(true);
    expect(names(vm.liveSolo), isEmpty);
    expect(names(vm.playedToday), ['Faker']);
    expect(names(vm.quiet), isEmpty);
  });

  test('구독은 화면을 먼저 바꾸고, 기본값과 다른 토글만 따로 보낸다', () async {
    final vm = await build();

    // 월즈 기본값은 시작·종료 둘 다 ON — 서버 기본값(종료 OFF)과 달라 토글을 보낸다.
    await vm.setSubscribed(2, true);
    expect(vm.subscribedInRoster, 2);
    verify(() => repo.subscribePlayer(2)).called(1);
    verify(
      () => repo.updatePlayerAlarm(2, startEnabled: true, endEnabled: true),
    ).called(1);

    await vm.setSubscribed(3, true, endEnabled: false);
    verifyNever(
      () => repo.updatePlayerAlarm(
        3,
        startEnabled: any(named: 'startEnabled'),
        endEnabled: any(named: 'endEnabled'),
      ),
    );
  });

  test('구독 요청이 실패하면 되돌린다', () async {
    when(() => repo.subscribePlayer(2)).thenThrow(Exception('down'));
    final vm = await build();

    await vm.setSubscribed(2, true);

    expect(vm.subscribedInRoster, 1);
    expect(
      vm.liveSolo.single.player.subscribed,
      isFalse,
      reason: 'Canyon 구독이 실패했으니 벨은 다시 꺼져 있어야 한다',
    );
  });

  test('리그를 고르면 그 리그 팀·선수만 남고, 팀 필터는 풀린다', () async {
    final vm = MyPlayersViewModel(
      subscriptions: repo,
      worlds: _FakeWorlds(
        WorldsSoloSnapshot(
          players: [
            _player(1, 'Faker', 'T1'),
            _player(2, 'Bin', 'BLG'),
            _player(3, 'Caps', 'G2'),
            _player(4, 'Knight', 'BLG'),
          ],
          solo: const SoloRankSnapshot(live: [], finished: []),
        ),
      ),
    );
    await vm.refresh();
    addTearDown(vm.dispose);

    expect(vm.leagueCodes, ['LCK', 'LPL', 'LEC']);
    vm.setTeamCode('T1');
    vm.setLeagueCode('LPL');
    expect(vm.teamCode, isNull);
    expect(vm.teamCodes, ['BLG']);
    expect(names(vm.quiet), ['Bin', 'Knight']);
  });
}
