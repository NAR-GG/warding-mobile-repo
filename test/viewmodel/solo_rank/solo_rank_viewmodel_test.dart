import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/domain/player_subscription.dart';
import 'package:warding/features/solo_rank/data/solo_rank_sources.dart';
import 'package:warding/features/solo_rank/domain/solo_rank_models.dart';
import 'package:warding/features/solo_rank/presentation/viewmodels/solo_rank_viewmodel.dart';
import 'package:warding/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:warding/features/subscription/presentation/viewmodels/subscribed_players_viewmodel.dart';

class _MockSubRepo extends Mock implements SubscriptionRepository {}

class _MockAuth extends Mock implements AuthService {}

class _FakeSoloSource implements SoloRankSource {
  _FakeSoloSource(this.snap);
  SoloRankSnapshot snap;
  @override
  Future<SoloRankSnapshot> fetch() async => snap;
}

class _FakeWorldsSource implements WorldsSoloSource {
  _FakeWorldsSource(this.snap);
  WorldsSoloSnapshot snap;
  @override
  Future<WorldsSoloSnapshot> fetch() async => snap;
}

class _FakeCheerSource implements CheerSource {
  @override
  Future<CheerResult> send(int playerId, int count) async =>
      const CheerResult(total: 0, mine: 0);
}

PlayerSubscription _sub(String name) => PlayerSubscription(
  playerId: name.hashCode,
  playerName: name,
  playerImageUrl: '',
  role: 'MID',
  teamId: 1,
  teamCode: 'T1',
  teamName: 'T1',
  teamImageUrl: '',
  subscribed: true,
  startEnabled: true,
  endEnabled: true,
);

LiveSoloPlayer _live(String name, int elapsed) => LiveSoloPlayer(
  name: name,
  teamCode: 'T1',
  champion: '아리',
  elapsedSeconds: elapsed,
);

FinishedSoloPlayer _fin(String name) => FinishedSoloPlayer(
  name: name,
  teamCode: 'T1',
  won: true,
  minutesAgo: 10,
);

const _emptyWorlds = WorldsSoloSnapshot(
  players: [],
  solo: SoloRankSnapshot(live: [], finished: []),
);

void main() {
  late _MockSubRepo subRepo;
  late _MockAuth auth;
  late SubscribedPlayersViewModel subs;

  SoloRankViewModel build({
    SoloRankSnapshot? solo,
    WorldsSoloSnapshot? worlds,
  }) => SoloRankViewModel(
    subscriptions: subs,
    source: _FakeSoloSource(
      solo ?? const SoloRankSnapshot(live: [], finished: []),
    ),
    worlds: _FakeWorldsSource(worlds ?? _emptyWorlds),
    cheer: _FakeCheerSource(),
  );

  void stubSubs(List<PlayerSubscription> players) {
    when(() => subRepo.fetchSubscribedPlayers())
        .thenAnswer((_) async => Right(players));
  }

  setUp(() {
    subRepo = _MockSubRepo();
    auth = _MockAuth();
    subs = SubscribedPlayersViewModel(repository: subRepo, auth: auth);
    when(() => auth.jwt).thenAnswer((_) async => 'token');
  });

  test('구독 조회가 끝나기 전에는 loading — 구독 0명과 구분한다', () {
    final vm = build();

    // 구분하지 않으면 응답이 오는 순간 빈 카드 → 실제 카드로 레이아웃이 튄다.
    expect(vm.cardState, SoloCardState.loading);
  });

  test('구독 0명이면 noSubscription', () async {
    stubSubs([]);
    final vm = build();

    await subs.load();

    expect(vm.cardState, SoloCardState.noSubscription);
  });

  test('구독은 있는데 진행 중·끝난 경기 0명이면 noneActive', () async {
    stubSubs([_sub('Faker')]);
    final vm = build();

    await subs.load();
    await vm.load();

    expect(vm.cardState, SoloCardState.noneActive);
  });

  test('진행 중 0명이어도 끝난 경기가 있으면 active', () async {
    stubSubs([_sub('Faker')]);
    final vm = build(
      solo: SoloRankSnapshot(live: const [], finished: [_fin('Faker')]),
    );

    await subs.load();
    await vm.load();

    expect(vm.cardState, SoloCardState.active);
    expect(vm.live, isEmpty);
    expect(vm.finished.single.name, 'Faker');
  });

  test('구독 목록이 늦게 와도 분류를 다시 한다', () async {
    stubSubs([_sub('Faker')]);
    final vm = build(
      solo: SoloRankSnapshot(
        live: [_live('Faker', 60), _live('모르는선수', 30)],
        finished: const [],
      ),
    );

    // 솔랭이 먼저 도착 — 구독 목록을 모르니 필터를 못 건다.
    await vm.load();
    // 구독이 뒤늦게 도착하면 구독한 선수만 남아야 한다.
    await subs.load();

    expect(vm.live.map((p) => p.name).toList(), ['Faker']);
  });

  test('핀 고정한 선수가 먼저, 그 안에서는 최근 시작 먼저', () async {
    stubSubs([_sub('A'), _sub('B'), _sub('C')]);
    final vm = build(
      solo: SoloRankSnapshot(
        live: [_live('A', 300), _live('B', 60), _live('C', 120)],
        finished: const [],
      ),
    );
    await subs.load();
    await vm.load();

    // 핀 없으면 경과 시간 짧은 순.
    expect(vm.live.map((p) => p.name).toList(), ['B', 'C', 'A']);

    vm.togglePin('A');

    expect(vm.live.first.name, 'A');
    expect(vm.pinnedNames, {'A'});
  });

  test('hiddenCount 는 어디에도 안 나온 구독 선수 수', () async {
    stubSubs([_sub('A'), _sub('B'), _sub('C')]);
    final vm = build(
      solo: SoloRankSnapshot(live: [_live('A', 60)], finished: [_fin('B')]),
    );
    await subs.load();
    await vm.load();

    expect(vm.subscribedTotal, 3);
    expect(vm.hiddenCount, 1);
  });

  test('진행 중 선수가 줄면 스와이프 위치를 처음으로 돌린다', () async {
    stubSubs([_sub('A'), _sub('B')]);
    final source = _FakeSoloSource(
      SoloRankSnapshot(
        live: [_live('A', 60), _live('B', 30)],
        finished: const [],
      ),
    );
    final vm = SoloRankViewModel(
      subscriptions: subs,
      source: source,
      worlds: _FakeWorldsSource(_emptyWorlds),
      cheer: _FakeCheerSource(),
    );
    await subs.load();
    await vm.load();
    vm.setSwipeIndex(1);

    source.snap = SoloRankSnapshot(live: [_live('A', 60)], finished: const []);
    await vm.load();

    expect(vm.swipeIndex, 0);
  });

  test('월즈 명단이 비면 섹션을 숨긴다', () async {
    stubSubs([]);
    final vm = build();

    await vm.loadWorlds();

    expect(vm.worldsVisible, isFalse);
  });

  test('월즈 카드에서 구독한 선수는 뺀다 — 위 큰 카드에 이미 나온다', () async {
    stubSubs([_sub('Faker')]);
    final vm = build(
      worlds: WorldsSoloSnapshot(
        players: [_sub('Faker'), _sub('Chovy')],
        solo: SoloRankSnapshot(
          live: [_live('Faker', 60), _live('Chovy', 30)],
          finished: const [],
        ),
      ),
    );

    await subs.load();
    await vm.loadWorlds();

    expect(vm.worldsVisible, isTrue);
    expect(vm.worldsLiveAll.length, 2);
    expect(vm.worldsLive.map((p) => p.name).toList(), ['Chovy']);
  });
}
