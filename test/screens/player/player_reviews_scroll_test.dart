import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/player_detail.dart';
import 'package:warding/repository/player/player_mock_source.dart';
import 'package:warding/repository/player/player_repository.dart';
import 'package:warding/screens/player/player_screen.dart';
import 'package:warding/viewmodel/player/player_viewmodel.dart';

/// 한줄평 조회만 항상 실패하는 소스(옛 서버·네트워크 장애 재현).
class _FailingReviews implements PlayerSource {
  const _FailingReviews();

  final PlayerSource _ok = const MockPlayerSource();

  @override
  Future<PlayerDetail> fetchDetail(int id) => _ok.fetchDetail(id);

  @override
  Future<PlayerWorlds> fetchWorlds(int id) => _ok.fetchWorlds(id);

  @override
  Future<PlayerSoloRank> fetchSoloRank(int id) => _ok.fetchSoloRank(id);

  @override
  Future<PlayerReviewPage> fetchWorldsReviews(int id, {int page = 0}) =>
      Future.error(Exception('boom'));
}

Widget _app(PlayerViewModel vm) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ko'),
  home: PlayerScreen(playerId: vm.playerId, viewModel: vm),
);

void main() {
  testWidgets('한줄평 무한 스크롤 — 바닥까지 내리면 끝까지 이어 받는다', (tester) async {
    tester.view.physicalSize = const Size(375, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = PlayerViewModel(
      playerId: 1,
      source: const MockPlayerSource(),
      isLoggedIn: () async => false,
    );
    await tester.pumpWidget(_app(vm));
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      if (!vm.reviewsHasNext && vm.allReviews != null) break;
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(vm.allReviews, isNotNull);
    expect(vm.allReviews!.length, greaterThan(20), reason: '여러 장을 이어 받는다');
    expect(vm.reviewsHasNext, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });

  testWidgets('한줄평 조회가 실패해도 매 프레임 재시도하지 않는다', (tester) async {
    // 콘텐츠보다 큰 캔버스 — 스크롤 여지가 없어 "짧으면 바로 당기기" 경로를 탄다.
    // 실패 후에도 계속 당기면 리빌드 루프에 빠져 화면이 멈췄었다.
    tester.view.physicalSize = const Size(375, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = PlayerViewModel(
      playerId: 1,
      source: const _FailingReviews(),
      isLoggedIn: () async => false,
    );
    await tester.pumpWidget(_app(vm));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(vm.reviewsFailed, isTrue, reason: '한 번 실패하면 더 시도하지 않는다');
    expect(vm.reviewsLoading, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
