import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/home_models.dart';
import 'package:warding/model/player_subscription.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_solo_rank_section.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import '../../support/fake_subscription_repository.dart';

/// 솔랭 카드 경과 시간 카운트업의 리빌드 범위.
///
/// 예전엔 1초 타이머가 `setState(() {})` 로 **섹션 전체**(챔피언 스플래시·선수
/// 사진·PageView·끝난 경기 칩 줄)를 다시 그렸고, 조건이 `soloState == active`
/// 라 **끝난 경기만 있어 카운트업할 대상이 없을 때도** 매초 돌았다(실측: 10초에
/// 섹션 빌드 10회). 지금은 경과 시간 텍스트만 구독해 갱신하고, 진행 중
/// (`soloLive`) 카드가 있을 때만 타이머를 켠다.
void main() {
  PlayerSubscription subOf(String name) => PlayerSubscription(
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

  Future<HomeViewModel> pumpSection(
    WidgetTester tester,
    SoloRankSnapshot snapshot,
  ) async {
    final repo = MockSubscriptionRepository();
    when(() => repo.fetchSubscribedPlayers())
        .thenAnswer((_) async => [subOf('Faker')]);
    final vm = HomeViewModel(
      subscriptions: repo,
      soloRank: _FixedSolo(snapshot),
      reviews: const MockReviewSource(),
      news: const MockNewsSource(),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: HomeSoloRankSection(viewModel: vm, scale: 1)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    return vm;
  }

  testWidgets('진행 중이면 경과 시간이 그려진다', (tester) async {
    final vm = await pumpSection(
      tester,
      SoloRankSnapshot(
        live: [
          HomeLiveSoloPlayer(
            name: 'Faker',
            teamCode: 'T1',
            champion: '아리',
            elapsedSeconds: 120,
            startedAt: DateTime.now().subtract(const Duration(seconds: 120)),
          ),
        ],
        finished: const [],
      ),
    );

    expect(vm.soloLive, hasLength(1));
    expect(find.text('2:00'), findsOneWidget);

    // 매초 틱이 돌아도 화면이 깨지지 않는다(텍스트만 갱신된다).
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomeSoloRankSection), findsOneWidget);

    // 솔랭 5초 폴링 타이머가 남아 있으면 테스트가 pending timer 로 실패한다.
    vm.pauseSoloPolling();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('끝난 경기만 있으면 카운트업 시계를 그리지 않는다', (tester) async {
    final vm = await pumpSection(
      tester,
      SoloRankSnapshot(
        live: const [],
        finished: [
          HomeFinishedSoloPlayer(
            name: 'Faker',
            teamCode: 'T1',
            won: true,
            minutesAgo: 30,
          ),
        ],
      ),
    );

    // 끝난 경기만 있어도 soloState 는 active 다 — 예전 타이머 조건이 이걸
    // 못 걸러 카운트업 대상이 없는데도 매초 섹션을 다시 그렸다.
    expect(vm.soloState, SoloCardState.active);
    expect(vm.soloLive, isEmpty);

    // 진행 중 카드가 없으니 경과 시간(mm:ss) 텍스트 자체가 없다.
    expect(find.textContaining(RegExp(r'^\d+:\d{2}$')), findsNothing);

    // 몇 초가 흘러도 마찬가지다(타이머가 꺼져 있다).
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining(RegExp(r'^\d+:\d{2}$')), findsNothing);

    vm.pauseSoloPolling();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FixedSolo implements SoloRankSource {
  _FixedSolo(this.snapshot);
  final SoloRankSnapshot snapshot;

  @override
  Future<SoloRankSnapshot> fetch() async => snapshot;
}
