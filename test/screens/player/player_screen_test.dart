import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_chip.dart';
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
    // 경기 날짜가 같은 줄 끝에 붙는다.
    expect(
      find.textContaining('LOS Grandes  스위스 1라운드  ', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // 한줄평은 "더 보기" 버튼 없이 스크롤로 이어 받는다. 콘텐츠가 화면보다
    // 짧으면 스크롤 여지가 없으므로 레이아웃 직후 바로 다음 장을 당긴다.
    expect(
      find.byKey(PlayerWorldsTab.reviewKey(19)),
      findsOneWidget,
      reason: '버튼을 누르지 않아도 다음 장이 붙는다',
    );
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(PlayerWorldsTab.reviewKey(39)).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(PlayerWorldsTab.reviewKey(39)),
      findsOneWidget,
      reason: '계속 내리면 계속 이어 붙는다',
    );

    // 정렬 칩은 공용 NarChip 기본 크기(34).
    final sortChip = find.ancestor(
      of: find.text('솔랭순'),
      matching: find.byType(NarChip),
    );
    await tester.ensureVisible(sortChip);
    expect(tester.getSize(sortChip).height, 34);

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
    // 최근 솔랭은 "더 보기"로 한 번에 전부 편다(이미 받아 둔 목록).
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
