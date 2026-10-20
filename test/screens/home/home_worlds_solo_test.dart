import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_solo_rank_section.dart';
import 'package:warding/screens/home/component/home_worlds_solo.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

PlayerSubscription _roster(int id, String name, String team) =>
    PlayerSubscription(
      playerId: id,
      playerName: name,
      playerImageUrl: '',
      role: 'MID',
      teamId: 0,
      teamCode: team,
      teamName: team,
      teamImageUrl: '',
      subscribed: false,
      startEnabled: true,
      endEnabled: false,
    );

HomeLiveSoloPlayer _worldsLive(int id, String name) => HomeLiveSoloPlayer(
  name: name,
  teamCode: 'GEN',
  champion: '',
  elapsedSeconds: 600,
  playerId: id,
  platform: 'NA1',
);

void main() {
  Widget section(HomeViewModel vm, {VoidCallback? onOpenWorlds}) =>
      HomeSoloRankSection(viewModel: vm, scale: 1, onOpenWorlds: onOpenWorlds);

  final worldsLive = WorldsSoloSnapshot(
    players: [
      _roster(1, 'Faker', 'T1'),
      _roster(2, 'Canyon', 'GEN'),
      _roster(3, 'Chovy', 'GEN'),
    ],
    solo: SoloRankSnapshot(
      live: [_worldsLive(2, 'Canyon'), _worldsLive(3, 'Chovy')],
      finished: const [],
    ),
  );

  testWidgets('구독 0명 — 빈 카드 대신 월즈 선수 큰 카드와 구독 바', (tester) async {
    setUpHomeApi();
    var opened = 0;
    final vm = await pumpHomeSection(
      tester,
      worlds: worldsLive,
      section: (vm) => section(vm, onOpenWorlds: () => opened++),
    );

    expect(vm.soloState, SoloCardState.noSubscription);
    expect(find.byKey(HomeSoloRankSection.emptyCardKey), findsNothing);
    expect(
      find.byKey(HomeSoloRankSection.worldsHeroKey('Canyon')),
      findsOneWidget,
    );
    expect(
      find.byKey(HomeSoloRankSection.worldsSubscribeKey('Canyon')),
      findsOneWidget,
    );
    expect(find.text('Canyon 구독하면'), findsOneWidget);

    await tester.tap(find.text('월즈 솔랭 전체'));
    expect(opened, 1);
  });

  testWidgets('구독 선수는 쉬는 중 — 조용한 줄 아래 월즈 작은 카드(구독 선수는 빼고)', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [subscriptionJson('Chovy', 'GEN')];
    final vm = await pumpHomeSection(
      tester,
      worlds: worldsLive,
      section: section,
    );

    expect(vm.soloState, SoloCardState.noneActive);
    expect(find.byKey(HomeSoloRankSection.quietKey), findsOneWidget);
    expect(find.byKey(HomeWorldsMiniCards.cardKey('Canyon')), findsOneWidget);
    expect(find.byKey(HomeWorldsMiniCards.cardKey('Chovy')), findsNothing);
    expect(find.text('NA'), findsOneWidget);
  });

  testWidgets('월즈 선수도 모두 쉬는 중 — 마지막 솔랭 한 줄로 접는다', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [subscriptionJson('Ruler', 'GEN')];
    await pumpHomeSection(
      tester,
      worlds: WorldsSoloSnapshot(
        players: [_roster(1, 'Faker', 'T1')],
        solo: const SoloRankSnapshot(
          live: [],
          finished: [
            HomeFinishedSoloPlayer(
              name: 'Faker',
              teamCode: 'T1',
              won: true,
              minutesAgo: 23,
            ),
          ],
        ),
      ),
      section: section,
    );

    expect(find.byKey(HomeWorldsLine.lineKey), findsOneWidget);
    expect(find.textContaining('마지막 Faker · 23분 전'), findsOneWidget);
    expect(find.byType(HomeWorldsMiniCards), findsNothing);
  });

  testWidgets('구독 선수가 솔랭 중 — 전체 버튼 아래 월즈 진입 줄 하나만', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [subscriptionJson('Faker', 'T1')];
    await pumpHomeSection(
      tester,
      solo: SoloRankSnapshot(
        live: [livePlayer('Faker', 300)],
        finished: const [],
      ),
      worlds: worldsLive,
      section: section,
    );

    expect(find.byKey(HomeSoloRankSection.heroKey('Faker')), findsOneWidget);
    expect(find.byKey(HomeWorldsEntryRow.rowKey), findsOneWidget);
    expect(find.text('LCK 선수 2명 솔랭 중'), findsOneWidget);
    expect(find.byType(HomeWorldsMiniCards), findsNothing);
  });

  testWidgets('명단이 비면 월즈 블록이 없다', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [subscriptionJson('Faker', 'T1')];
    await pumpHomeSection(tester, section: section);

    expect(find.byKey(HomeWorldsLine.lineKey), findsNothing);
    expect(find.byKey(HomeWorldsEntryRow.rowKey), findsNothing);
  });
}
