import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/cheer_ad_banner.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/repository/ad/ad_repository.dart';

/// 응원 광고 배너의 좌우 여백. 홈은 기본값 16 을 쓰고, 경기 리스트·경기 상세는
/// 0 을 넘겨 폭을 꽉 채운다.
///
/// 광고 자리는 응답을 기다리는 동안 빈 자리(AdLoadingSlot)였다가 모집 배너가 된다. 둘의
/// 크기가 같아야 자리가 출렁이지 않으므로, 상태와 상관없이 자리 전체([_slot])를 잰다.
/// (광고 조회 Future 는 싱글턴 캐시라 앞 테스트의 fake async 존에 묶여 이후 테스트에선
/// 끝나지 않는다 — 그래서 모집 배너가 그려졌는지에 기대지 않는다.)
final _slot = find.byType(FutureBuilder<Ad?>);

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ko'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('기본값은 좌우 16 여백을 둔다', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const CheerAdBanner(placement: 'home', scale: 1)),
    );
    await tester.pumpAndSettle();

    final card = tester.getSize(_slot);
    expect(card.width, 375 - 32);
  });

  testWidgets('horizontalPadding 0 이면 화면 폭을 꽉 채운다', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const CheerAdBanner(
          placement: 'match_list',
          scale: 1,
          horizontalPadding: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.getSize(_slot);
    expect(card.width, 375);
  });

  testWidgets('홈(20)은 다른 섹션과, 경기 리스트·상세(8)는 더 넓게 그려진다', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 홈 섹션들은 모두 EdgeInsets.symmetric(horizontal: 20 * scale) 를 쓴다.
    await tester.pumpWidget(
      _host(
        const CheerAdBanner(placement: 'home', scale: 1, horizontalPadding: 20),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_slot).width, 375 - 40);

    await tester.pumpWidget(
      _host(
        const CheerAdBanner(
          placement: 'match_list',
          scale: 1,
          horizontalPadding: 8,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_slot).width, 375 - 16);
  });

  testWidgets('세 자리(배너·스플래시·팝업) 모두에 AD 뱃지가 붙는다', (tester) async {
    tester.view.physicalSize = const Size(375, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final slot in CheerAdSlot.values) {
      await tester.pumpWidget(_host(CheerAdBannerCard(scale: 1, slot: slot)));
      await tester.pump();

      expect(find.text('AD'), findsOneWidget, reason: '$slot 에 AD 뱃지가 없다');
    }
  });

  testWidgets('배너 자리는 960x300 비율로 그려진다', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const CheerAdBanner(
          placement: 'match_detail',
          scale: 1,
          horizontalPadding: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.getSize(_slot);
    expect(card.width / card.height, closeTo(960 / 300, 0.01));
  });
}
