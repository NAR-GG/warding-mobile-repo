import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_tab_bar.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/repository/player/player_mock_source.dart';
import 'package:warding/screens/player/component/player_solo_tab.dart';
import 'package:warding/screens/player/component/player_worlds_tab.dart';
import 'package:warding/screens/player/player_screen.dart';
import 'package:warding/viewmodel/player/player_viewmodel.dart';

Widget _app(PlayerViewModel vm) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ko'),
  home: PlayerScreen(playerId: vm.playerId, viewModel: vm),
);

PlayerViewModel _vm(int id) => PlayerViewModel(
  playerId: id,
  source: const MockPlayerSource(),
  isLoggedIn: () async => false,
);

void main() {
  testWidgets('솔랭 중 — 큰 카드·다음 경기(단판)·월즈 탭', (tester) async {
    tester.view.physicalSize = const Size(375, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = _vm(1);
    await tester.pumpWidget(_app(vm));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(PlayerScreen.liveKey), findsOneWidget);
    expect(find.text('단판'), findsOneWidget);
    expect(find.textContaining('월즈 성적'), findsOneWidget);
    expect(find.text('LOS Grandes  스위스 1라운드'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 한줄평: 미리보기 3개 → "한줄평 전체 N개 보기" 로 20개.
    expect(find.byKey(PlayerWorldsTab.reviewKey(2)), findsOneWidget);
    expect(find.byKey(PlayerWorldsTab.reviewKey(3)), findsNothing);
    await tester.ensureVisible(find.byKey(PlayerWorldsTab.reviewsAllKey));
    expect(find.text('한줄평 전체 412개 보기'), findsOneWidget);
    await tester.tap(find.byKey(PlayerWorldsTab.reviewsAllKey));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(PlayerWorldsTab.reviewKey(19)), findsOneWidget);
    expect(find.text('한줄평 더 보기'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 20000));
    await tester.pump();

    await tester.tap(
      find.descendant(of: find.byType(NarTabBar), matching: find.text('솔랭')),
    );
    await tester.pump();
    expect(find.byType(PlayerSoloTab), findsOneWidget);
    // 솔랭에서 만난 선수 — 다음 경기 상대 팀(HLE)이면 태그가 붙는다.
    await tester.ensureVisible(find.byKey(PlayerSoloTab.metKey(223)));
    expect(
      find.descendant(
        of: find.byKey(PlayerSoloTab.metKey(223)),
        matching: find.text('다음 상대'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(PlayerSoloTab.metKey(2)),
        matching: find.text('다음 상대'),
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.byKey(PlayerSoloTab.moreKey));
    await tester.tap(find.byKey(PlayerSoloTab.moreKey));
    await tester.pump();
    expect(find.byKey(PlayerSoloTab.moreKey), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('쉬는 중 + 기록 집계 중', (tester) async {
    tester.view.physicalSize = const Size(375, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = _vm(12);
    await tester.pumpWidget(_app(vm));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(PlayerScreen.restingKey), findsOneWidget);
    expect(find.byKey(PlayerWorldsTab.pendingKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
