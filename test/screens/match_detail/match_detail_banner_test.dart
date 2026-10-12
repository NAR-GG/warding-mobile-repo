import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/advertiser_banner.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/match_detail/match_detail_screen.dart';

/// 광고 배너는 화면에 한 번만. 잠금(경기 전) 탭은 맨 아래에 붙는다.
/// (경기 데이터가 있을 때 픽·스탯 사이 배치는 레포지토리 주입 지점이 없어 실기기로 확인.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('잠금 상태: 배너가 한 번만 뜬다', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: const MatchDetailScreen(matchId: 'm-1'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AdvertiserBanner), findsOneWidget);
  });
}
