import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/repository/home/home_sources.dart';
import 'package:warding/screens/home/component/home_solo_rank_section.dart';
import 'package:warding/viewmodel/home/home_viewmodel.dart';

import 'home_test_harness.dart';

/// 솔랭 카드 — spec "상태" 표의 세 갈래(구독 0명 / 진행 중 0명 / 진행 중)와
/// "결정"의 표시 규칙(라이브 카드의 숫자는 경과 시간 하나, 끝난 카드는
/// "N분 전 종료", 경기 길이는 "32분")을 확인한다.
void main() {
  Widget section(
    HomeViewModel vm, {
    VoidCallback? onOpenMyPlayers,
    VoidCallback? onSubscribe,
  }) => HomeSoloRankSection(
    viewModel: vm,
    scale: 1,
    onOpenMyPlayers: onOpenMyPlayers,
    onSubscribe: onSubscribe,
  );

  testWidgets('비회원은 구독 0명 — 점선 빈 카드와 빈 프로필, 구독하기 버튼', (tester) async {
    setUpHomeApi();
    var subscribeTaps = 0;
    final vm = await pumpHomeSection(
      tester,
      // 목업 솔랭 소스가 27명·진행 중 4명을 줘도 비회원은 0명으로 본다.
      solo: const SoloRankSnapshot(
        live: MockSoloRankSource.live,
        finished: MockSoloRankSource.finished,
        subscribedTotal: MockSoloRankSource.subscribedTotal,
      ),
      section: (vm) => section(vm, onSubscribe: () => subscribeTaps++),
    );

    expect(vm.soloState, SoloCardState.noSubscription);
    final empty = find.byKey(HomeSoloRankSection.emptyCardKey);
    expect(empty, findsOneWidget);
    // 카드 테두리 + 빈 프로필 원, 둘 다 점선.
    expect(
      find.descendant(of: empty, matching: find.byType(DashedBorder)),
      findsNWidgets(2),
    );
    expect(find.text('응원하는 선수를 구독하면\n솔랭 소식이 여기 떠요'), findsOneWidget);
    expect(find.byKey(HomeSoloRankSection.heroKey('Faker')), findsNothing);
    expect(find.textContaining('구독 27명'), findsNothing);

    await tester.tap(find.text('선수 구독하기'));
    expect(subscribeTaps, 1);
  });

  testWidgets('구독은 있는데 진행 중 0명 — 한 줄짜리 조용한 상태', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [
      subscriptionJson('Faker', 'T1'),
      subscriptionJson('Chovy', 'GEN'),
      subscriptionJson('Oner', 'T1'),
    ];
    var opened = 0;
    final vm = await pumpHomeSection(
      tester,
      solo: SoloRankSnapshot(
        live: const [],
        finished: [finishedPlayer('Chovy', 130)],
        subscribedTotal: 0,
      ),
      section: (vm) => section(vm, onOpenMyPlayers: () => opened++),
    );

    expect(vm.soloState, SoloCardState.noneActive);
    final quiet = find.byKey(HomeSoloRankSection.quietKey);
    expect(quiet, findsOneWidget);
    expect(find.text('지금 솔랭 중인 선수 없음'), findsOneWidget);
    expect(find.textContaining('구독 3명'), findsOneWidget);
    expect(find.textContaining('Chovy 승리'), findsOneWidget);
    // 큰 카드·끝난 경기 줄·빈 카드는 없다.
    expect(find.byType(PageView), findsNothing);
    expect(find.byKey(HomeSoloRankSection.emptyCardKey), findsNothing);
    expect(find.text('오늘 끝난 경기'), findsNothing);

    await tester.tap(quiet);
    expect(opened, 1);
  });

  testWidgets('빈 솔랭 소스(릴리즈 기본) + 구독 있음 — 조용한 행, 누르면 내 선수', (
    tester,
  ) async {
    final server = setUpHomeApi(loggedIn: true);
    server.subscriptions = [
      subscriptionJson('Faker', 'T1'),
      subscriptionJson('Chovy', 'GEN'),
    ];
    var opened = 0;
    late SoloRankSnapshot empty;
    await tester.runAsync(
      () async => empty = await const EmptySoloRankSource().fetch(),
    );
    final vm = await pumpHomeSection(
      tester,
      solo: empty,
      section: (vm) => section(vm, onOpenMyPlayers: () => opened++),
    );

    expect(vm.soloState, SoloCardState.noneActive);
    final quiet = find.byKey(HomeSoloRankSection.quietKey);
    expect(quiet, findsOneWidget);
    expect(find.textContaining('구독 2명'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    await tester.tap(quiet);
    expect(opened, 1);
  });

  testWidgets('진행 중 — 큰 카드의 숫자는 경과 시간뿐, 아래 끝난 줄은 "N분 전 종료"', (tester) async {
    final server = setUpHomeApi(loggedIn: true);
    // 솔랭 항목은 구독한 선수만 보이므로 Faker·Oner·Ruler 를 포함해 10명.
    server.subscriptions = [
      for (final n in ['Faker', 'Oner', 'Ruler']) subscriptionJson(n, 'GEN'),
      for (var i = 3; i < 10; i++) subscriptionJson('P$i', 'GEN'),
    ];
    var opened = 0;
    await pumpHomeSection(
      tester,
      solo: SoloRankSnapshot(
        live: [livePlayer('Faker', 1452)],
        finished: [
          finishedPlayer('Oner', 12, durationMinutes: 32),
          finishedPlayer('Ruler', 40, won: false),
        ],
        subscribedTotal: 0,
      ),
      section: (vm) => section(vm, onOpenMyPlayers: () => opened++),
    );

    final hero = find.byKey(HomeSoloRankSection.heroKey('Faker'));
    expect(hero, findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.text('24:12')),
      findsOneWidget,
    );

    // spectator-v5 가 주지 않는 값은 그리지 않는다.
    expect(find.textContaining('관전'), findsNothing);
    expect(find.textContaining('포지션'), findsNothing);
    expect(
      find.textContaining(RegExp(r'\d+\s*/\s*\d+\s*/\s*\d+')),
      findsNothing,
    );

    // 라이브 카드에서 숫자가 들어간 글자는 경과 시간 하나뿐이다.
    final numericTexts = tester
        .widgetList<Text>(
          find.descendant(of: hero, matching: find.byType(Text)),
        )
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((s) => RegExp(r'\d').hasMatch(s))
        .toList();
    expect(numericTexts, ['24:12']);

    // 끝난 카드: 종료 시각은 "N분 전 종료", 경기 길이는 "32분"(플레이 없음).
    final oner = find.byKey(HomeSoloRankSection.finishedKey('Oner'));
    expect(oner, findsOneWidget);
    expect(
      find.descendant(of: oner, matching: find.textContaining('12분 전 종료')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: oner, matching: find.text('32분')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: oner, matching: find.textContaining('플레이')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(HomeSoloRankSection.finishedKey('Ruler')),
        matching: find.textContaining('40분 전 종료'),
      ),
      findsOneWidget,
    );

    // 위·아래 어디에도 안 나온 선수 수 — 줄 끝에 있어 밀어서 확인한다.
    await tester.scrollUntilVisible(
      find.text('+7명'),
      100,
      scrollable: find
          .ancestor(of: oner, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('+7명'), findsOneWidget);
    await tester.tap(find.text('구독 10명 전체'));
    expect(opened, 1);
  });
}
