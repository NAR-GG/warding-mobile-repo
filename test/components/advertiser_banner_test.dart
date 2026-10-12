import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/components/advertiser_banner.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/notice/ad_guide_screen.dart';
import 'package:warding/util/api_client.dart' as api;

void main() {
  testWidgets('광고주 모집 배너를 누르면 광고 안내 화면으로 이동한다', (tester) async {
    api.setApiClientForTesting(MockClient((_) async => http.Response('', 404)));
    addTearDown(() => api.setApiClientForTesting(null));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('ko'),
        home: Scaffold(body: AdvertiserBanner(scale: 1)),
      ),
    );

    await tester.tap(find.byType(AdvertiserBanner));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AdGuideScreen), findsOneWidget);
  });
}
