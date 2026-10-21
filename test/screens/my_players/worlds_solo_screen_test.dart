import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/my_players/component/worlds_player_sheet.dart';
import 'package:warding/screens/my_players/my_players_screen.dart';
import 'package:warding/viewmodel/my_players/my_players_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';

class _FakeWorlds implements WorldsSoloSource {
  _FakeWorlds(this.snap);
  final WorldsSoloSnapshot snap;
  @override
  Future<WorldsSoloSnapshot> fetch() async => snap;
}

PlayerSubscription _player(int id, String name, {bool subscribed = false}) =>
    PlayerSubscription(
      playerId: id,
      playerName: name,
      playerImageUrl: '',
      role: 'MID',
      teamId: 0,
      teamCode: 'GEN',
      teamName: 'GEN',
      teamImageUrl: '',
      subscribed: subscribed,
      startEnabled: true,
      endEnabled: false,
    );

void main() {
  late MockSubscriptionRepository repo;

  Future<MyPlayersViewModel> buildVm(WidgetTester tester) async {
    // 로그인 상태 — 시트의 구독 버튼은 비회원이면 로그인으로 보낸다.
    FlutterSecureStorage.setMockInitialValues({'jwt': 'test-jwt'});
    AuthService.instance.resetJwtCacheForTesting();
    repo = MockSubscriptionRepository();
    when(() => repo.subscribePlayer(any())).thenAnswer(
      (inv) async => _player(inv.positionalArguments.first as int, ''),
    );
    when(
      () => repo.updatePlayerAlarm(
        any(),
        startEnabled: any(named: 'startEnabled'),
        endEnabled: any(named: 'endEnabled'),
      ),
    ).thenAnswer((_) async {});
    late MyPlayersViewModel vm;
    await tester.runAsync(() async {
      vm = MyPlayersViewModel(
        subscriptions: repo,
        worlds: _FakeWorlds(
          WorldsSoloSnapshot(
            players: [
              _player(1, 'Chovy', subscribed: true),
              _player(2, 'Canyon'),
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
              finished: [],
            ),
            today: const {2: WorldsTodayRecord(games: 3, wins: 2, losses: 0)},
          ),
        ),
      );
      await vm.refresh();
    });
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> pumpScreen(WidgetTester tester, MyPlayersViewModel vm) async {
    tester.view.physicalSize = const Size(375, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: MyPlayersScreen(viewModel: vm),
      ),
    );
    await tester.pump();
  }

  testWidgets('월즈 화면 — 제목·탭·NA 표시, 탭을 바꾸면 구독 선수만', (tester) async {
    final vm = await buildVm(tester);
    await pumpScreen(tester, vm);

    expect(find.text('월즈 솔랭'), findsOneWidget);
    expect(find.text('전체 선수 2'), findsOneWidget);
    expect(find.text('구독 선수 1'), findsOneWidget);
    expect(find.text('NA'), findsOneWidget);
    expect(find.byKey(MyPlayersScreen.tileKey(2)), findsOneWidget);

    await tester.tap(find.text('구독 선수 1'));
    await tester.pump();
    expect(find.byKey(MyPlayersScreen.tileKey(2)), findsNothing);
    expect(find.byKey(MyPlayersScreen.tileKey(1)), findsOneWidget);
  });

  testWidgets('벨을 누르면 바로 바꾸지 않고 선수 시트를 띄우고, 시트에서 구독한다', (tester) async {
    final vm = await buildVm(tester);
    await pumpScreen(tester, vm);

    await tester.tap(find.byKey(MyPlayersScreen.bellKey(2)));
    // 진행 중 배너의 점이 계속 깜빡여 settle 되지 않는다 — 시트 등장만 기다린다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorldsPlayerSheet), findsOneWidget);
    verifyNever(() => repo.subscribePlayer(any()));

    await tester.tap(find.byKey(WorldsPlayerSheet.subscribeKey));
    await tester.pumpAndSettle();

    verify(() => repo.subscribePlayer(2)).called(1);
    expect(find.text('구독 선수 2'), findsOneWidget);
  });

  testWidgets('줄을 누르면 선수 시트 — 알림 토글과 구독하기', (tester) async {
    final vm = await buildVm(tester);
    await pumpScreen(tester, vm);

    await tester.tap(find.byKey(MyPlayersScreen.tileKey(2)));
    // 진행 중 배너의 점이 계속 깜빡여 settle 되지 않는다 — 시트 등장만 기다린다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorldsPlayerSheet), findsOneWidget);
    // 진행 중 배너와 오늘 전적
    expect(find.text('솔로 랭크 진행 중'), findsOneWidget);
    expect(find.text('12:05'), findsOneWidget);
    expect(find.text('3판'), findsOneWidget);
    expect(find.text('2승 0패', findRichText: true), findsOneWidget);
    expect(find.text('솔랭 시작 알림'), findsOneWidget);
    expect(find.text('솔랭 종료 알림'), findsOneWidget);

    await tester.tap(find.byKey(WorldsPlayerSheet.subscribeKey));
    await tester.pumpAndSettle();

    verify(() => repo.subscribePlayer(2)).called(1);
    expect(find.byType(WorldsPlayerSheet), findsNothing);
  });

  testWidgets('startedAt 이 있으면 목록이 기기 시계로 경과를 다시 센다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 'test-jwt'});
    AuthService.instance.resetJwtCacheForTesting();
    repo = MockSubscriptionRepository();
    late MyPlayersViewModel vm;
    await tester.runAsync(() async {
      vm = MyPlayersViewModel(
        subscriptions: repo,
        worlds: _FakeWorlds(
          WorldsSoloSnapshot(
            players: [_player(1, 'Chovy', subscribed: true)],
            solo: SoloRankSnapshot(
              live: [
                HomeLiveSoloPlayer(
                  name: 'Chovy',
                  teamCode: 'GEN',
                  champion: '아리',
                  // 서버 스냅샷(10분)은 조회 시점 값이라 이미 낡았다.
                  // 시작 시각이 20분 전이므로 화면은 20분대를 보여야 한다.
                  elapsedSeconds: 600,
                  startedAt: DateTime.now().subtract(
                    const Duration(minutes: 20),
                  ),
                ),
              ],
              finished: const [],
            ),
            today: const {},
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: MyPlayersScreen(viewModel: vm, worlds: true),
      ),
    );
    await tester.pump();

    // 스냅샷(10:00)이 아니라 시작 시각 기준(20:00대)으로 센다.
    expect(find.textContaining('20:0'), findsOneWidget);
    expect(find.textContaining('10:0'), findsNothing);

    // 틱이 돌아도 화면이 깨지지 않는다(실제 시간은 테스트에서 흐르지 않으므로
    // 값 증가 자체는 live_elapsed_test 가 검증한다).
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('20:0'), findsOneWidget);
  });
}
