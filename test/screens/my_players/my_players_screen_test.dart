import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/components/nar_chip_multi_select.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_solo_rank_section.dart';
import 'package:warding/screens/my_players/component/my_player_tile.dart';
import 'package:warding/screens/my_players/my_players_screen.dart';
import 'package:warding/viewmodel/my_players/my_players_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';
import '../home/home_test_harness.dart';

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

PlayerSubscription _sub(String name, String teamCode) => PlayerSubscription(
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

/// 팀 10개 × 10명. T1 앞 3명과 GEN 앞 2명만 실명.
List<PlayerSubscription> _hundred() {
  final named = {
    'T1': ['Faker', 'Keria', 'Oner'],
    'GEN': ['Chovy', 'Canyon'],
  };
  return [
    for (final team in _teams)
      for (var i = 0; i < 10; i++)
        _sub(
          i < (named[team]?.length ?? 0) ? named[team]![i] : '$team-p$i',
          team,
        ),
  ];
}

const _solo = SoloRankSnapshot(
  live: [
    HomeLiveSoloPlayer(
      name: 'Faker',
      teamCode: 'T1',
      champion: '아리',
      elapsedSeconds: 1452,
    ),
    HomeLiveSoloPlayer(
      name: 'Chovy',
      teamCode: 'GEN',
      champion: '신드라',
      elapsedSeconds: 698,
    ),
  ],
  finished: [
    HomeFinishedSoloPlayer(
      name: 'Oner',
      teamCode: 'T1',
      won: true,
      minutesAgo: 12,
    ),
    HomeFinishedSoloPlayer(
      name: 'Canyon',
      teamCode: 'GEN',
      won: false,
      minutesAgo: 40,
    ),
  ],
  subscribedTotal: 0,
);

Future<MyPlayersViewModel> _buildVm(
  WidgetTester tester, {
  List<PlayerSubscription>? players,
}) async {
  final repo = MockSubscriptionRepository();
  final list = players ?? _hundred();
  when(() => repo.fetchSubscribedPlayers()).thenAnswer((_) async => list);
  late MyPlayersViewModel vm;
  await tester.runAsync(() async {
    vm = MyPlayersViewModel(
      subscriptions: repo,
      soloRank: FakeSoloSource(_solo),
    );
    await vm.refresh();
  });
  addTearDown(vm.dispose);
  return vm;
}

/// 홈 자리에 "열기" 버튼을 두고, 눌러서 내 선수 화면을 push 한다 —
/// 뒤로가기가 홈으로 돌아오는지 볼 수 있게.
Future<void> _pumpScreen(WidgetTester tester, MyPlayersViewModel vm) async {
  tester.view.physicalSize = const Size(375, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MyPlayersScreen(viewModel: vm),
              ),
            ),
            child: const Text('HOME'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('HOME'));
  await tester.pumpAndSettle();
}

/// 헤더 좌측 뒤로가기 아이콘.
Finder _backButton() => find.byWidgetPredicate((w) {
  if (w is! SvgPicture) return false;
  final loader = w.bytesLoader;
  return loader is SvgAssetLoader &&
      loader.assetName == 'assets/icons/chevron-left.svg';
});

Finder _teamChip(String label) => find.descendant(
  of: find.byType(NarChipMultiSelect),
  matching: find.text(label),
);

void main() {
  testWidgets('검색줄·팀 칩·세 묶음 제목을 그린다', (tester) async {
    final vm = await _buildVm(tester);
    await _pumpScreen(tester, vm);

    expect(find.text('내 선수'), findsOneWidget);
    expect(find.byKey(MyPlayersScreen.searchFieldKey), findsOneWidget);
    expect(find.text('선수 검색'), findsOneWidget);

    expect(_teamChip('전체'), findsOneWidget);
    for (final team in _teams) {
      expect(_teamChip(team), findsOneWidget, reason: team);
    }

    expect(find.text('지금 솔랭 중'), findsOneWidget);
    expect(find.text('오늘 경기함'), findsOneWidget);
    expect(find.text('오늘 소식 없음'), findsOneWidget);
    expect(find.text('96명'), findsOneWidget);

    expect(find.byKey(MyPlayersScreen.tileKey('Faker')), findsOneWidget);
    expect(find.byKey(MyPlayersScreen.tileKey('Oner')), findsOneWidget);
    // 소식 없음은 앞 5명만.
    expect(find.byKey(MyPlayersScreen.tileKey('Keria')), findsOneWidget);
    expect(find.byKey(MyPlayersScreen.tileKey('GEN-p9')), findsNothing);
  });

  testWidgets('"N명 더 보기"를 누르면 펼치고, 접기로 다시 접는다', (tester) async {
    final vm = await _buildVm(tester);
    await _pumpScreen(tester, vm);

    expect(find.text('91명 더 보기'), findsOneWidget);
    await tester.tap(find.byKey(MyPlayersScreen.showMoreKey));
    await tester.pump();

    expect(vm.quietExpanded, isTrue);
    expect(find.text('91명 더 보기'), findsNothing);
    expect(find.byKey(MyPlayersScreen.tileKey('T1-p5')), findsOneWidget);

    // 100명을 한꺼번에 만들지 않는다 — 화면 밖 줄은 지연 생성.
    expect(find.byType(MyPlayerTile).evaluate().length, lessThan(96));

    await tester.scrollUntilVisible(
      find.byKey(MyPlayersScreen.showMoreKey),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byKey(MyPlayersScreen.showMoreKey));
    await tester.pumpAndSettle();
    expect(find.text('접기'), findsOneWidget);
    await tester.tap(find.byKey(MyPlayersScreen.showMoreKey));
    await tester.pump();
    expect(vm.quietExpanded, isFalse);
  });

  testWidgets('검색어를 치면 이름으로 거른다', (tester) async {
    final vm = await _buildVm(tester);
    await _pumpScreen(tester, vm);

    await tester.enterText(find.byKey(MyPlayersScreen.searchFieldKey), 'FAK');
    await tester.pump();

    expect(vm.query, 'FAK');
    expect(find.byKey(MyPlayersScreen.tileKey('Faker')), findsOneWidget);
    expect(find.byKey(MyPlayersScreen.tileKey('Oner')), findsNothing);
    // 비어 버린 묶음은 제목도 그리지 않는다.
    expect(find.text('오늘 경기함'), findsNothing);
    expect(find.text('오늘 소식 없음'), findsNothing);

    await tester.enterText(find.byKey(MyPlayersScreen.searchFieldKey), 'zzz');
    await tester.pump();
    expect(find.text('찾는 선수가 없어요'), findsOneWidget);
  });

  testWidgets('팀 칩으로 거르고 "전체"로 되돌린다', (tester) async {
    final vm = await _buildVm(tester);
    await _pumpScreen(tester, vm);

    await tester.tap(_teamChip('GEN'));
    await tester.pump();
    expect(vm.teamCode, 'GEN');
    expect(find.byKey(MyPlayersScreen.tileKey('Chovy')), findsOneWidget);
    expect(find.byKey(MyPlayersScreen.tileKey('Faker')), findsNothing);

    // 고른 칩을 다시 눌러도 전체로 돌아간다.
    await tester.tap(_teamChip('GEN'));
    await tester.pump();
    expect(vm.teamCode, isNull);

    await tester.tap(_teamChip('T1'));
    await tester.pump();
    expect(vm.teamCode, 'T1');
    await tester.tap(_teamChip('전체'));
    await tester.pump();
    expect(vm.teamCode, isNull);
    expect(find.byKey(MyPlayersScreen.tileKey('Chovy')), findsOneWidget);
  });

  testWidgets('보기 전용 — 알림 벨이 없고 로딩·에러 UI도 없다', (tester) async {
    final vm = await _buildVm(tester);
    await _pumpScreen(tester, vm);

    expect(find.byIcon(Icons.notifications), findsNothing);
    expect(find.byIcon(Icons.notifications_none), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    final bells = find.byWidgetPredicate((w) {
      if (w is! SvgPicture) return false;
      final loader = w.bytesLoader;
      return loader is SvgAssetLoader && loader.assetName.contains('bell');
    });
    expect(bells, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('구독 0명(비회원 포함)이면 빈 안내 한 줄만 — 스피너 없음', (tester) async {
    final vm = await _buildVm(tester, players: const []);
    await _pumpScreen(tester, vm);

    expect(find.text('구독한 선수가 없어요'), findsOneWidget);
    expect(find.byType(MyPlayerTile), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('뒤로가기를 누르면 홈으로 돌아온다', (tester) async {
    final vm = await _buildVm(tester);
    await _pumpScreen(tester, vm);

    expect(find.byType(MyPlayersScreen), findsOneWidget);
    await tester.tap(_backButton());
    await tester.pumpAndSettle();
    expect(find.byType(MyPlayersScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  // 홈 화면 전체(HomeScreen)는 테스트에서 띄우지 않는다(하단 네비·스플래시
  // 이미지 등 네트워크가 얽힘). 대신 홈과 똑같이 연결한 솔랭 섹션의
  // "구독 N명 전체"가 이 화면을 push 하는지 본다.
  testWidgets('홈 솔랭 카드의 "구독 N명 전체"가 내 선수 화면을 연다', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [
      for (var i = 0; i < 12; i++) subscriptionJson('Sub$i', 'T1'),
    ];
    final myVm = await _buildVm(tester);
    await pumpHomeSection(
      tester,
      solo: SoloRankSnapshot(
        live: [livePlayer('Sub0', 60)],
        finished: const [],
        subscribedTotal: 0,
      ),
      section: (vm) => Builder(
        builder: (context) => HomeSoloRankSection(
          viewModel: vm,
          scale: 1,
          onOpenMyPlayers: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MyPlayersScreen(viewModel: myVm),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('구독 12명 전체'));
    await tester.pumpAndSettle();
    expect(find.byType(MyPlayersScreen), findsOneWidget);

    await tester.tap(_backButton());
    await tester.pumpAndSettle();
    expect(find.byType(MyPlayersScreen), findsNothing);
    expect(find.byType(HomeSoloRankSection), findsOneWidget);
  });
}
