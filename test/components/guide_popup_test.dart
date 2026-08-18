import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/guide_popup.dart';
import 'package:warding/components/nar_button.dart';
import 'package:warding/l10n/app_localizations.dart';

Widget _host({bool allowPostpone = true}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ko'),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showGuidePopup(
            context,
            allowPostpone: allowPostpone,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('시안의 문구·버튼 2개가 그려진다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('와딩 200% 즐기기'), findsOneWidget);
    expect(find.text('환영해요! 와딩 사용 꿀팁이 도착했어요'), findsOneWidget);
    expect(
      find.text('지금 보지 않아도 [마이페이지 > 와딩 사용가이드]에서 언제든 다시 볼 수 있어요.'),
      findsOneWidget,
    );
    expect(find.text('다음에 볼게요'), findsOneWidget);
    expect(find.text('가이드 보기'), findsOneWidget);
    expect(find.byType(NarButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('직접 열었을 때는 다음에 볼게요를 감춘다', (tester) async {
    await tester.pumpWidget(_host(allowPostpone: false));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('다음에 볼게요'), findsNothing);
    expect(find.text('가이드 보기'), findsOneWidget);
    expect(find.byType(NarButton), findsOneWidget);
  });

  testWidgets('가이드 보기를 누르면 닫힌다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가이드 보기'));
    await tester.pumpAndSettle();

    expect(find.text('환영해요! 와딩 사용 꿀팁이 도착했어요'), findsNothing);
  });

  testWidgets('가이드 이미지를 시안 크기(185×331)로 그린다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/guide.png');
    // 테스트 화면 폭 800 → scale 은 clamp(430)/375.
    const scale = 430 / 375;
    expect(image.width, closeTo(185 * scale, 0.01));
    expect(image.height, closeTo(331 * scale, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('가이드 미리보기 이미지에 3x 변형이 등록돼 있다', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 1x 만 있으면 2~3x 기기에서 확대돼 흐려진다.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final variants = manifest.getAssetVariants('assets/images/guide.png') ?? [];
    expect(
      variants.any((v) => v.targetDevicePixelRatio == 3.0),
      isTrue,
      reason: 'guide.png 에 3x 변형이 없다',
    );
  });

  testWidgets('에셋을 못 읽어도 팝업이 깨지지 않는다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // errorBuilder 가 자리를 잡아 주므로 렌더 예외가 없어야 한다.
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.errorBuilder, isNotNull);
    expect(find.text('가이드 보기'), findsOneWidget);
  });
}
