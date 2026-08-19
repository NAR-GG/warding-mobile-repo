import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/guide/component/guide_callout.dart';
import 'package:warding/screens/guide/component/guide_progress_bar.dart';
import 'package:warding/screens/guide/guide_page_data.dart';
import 'package:warding/screens/guide/guide_screen.dart';
import 'package:warding/screens/guide/page/guide_page_1.dart';
import 'package:warding/screens/guide/page/guide_page_2.dart';
import 'package:warding/screens/guide/page/guide_page_3.dart';
import 'package:warding/screens/guide/page/guide_page_4.dart';
import 'package:warding/screens/guide/page/guide_page_5.dart';
import 'package:warding/screens/guide/page/guide_page_6.dart';

Widget _host({int pages = 1}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ko'),
    home: Builder(
      builder: (context) => GuideScreen(
        pages: [for (var i = 0; i < pages; i++) guidePage1(context)],
      ),
    ),
  );
}

void main() {
  testWidgets('1장의 문구·헤더가 그려지고 오버플로가 없다', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('가이드 종료하기'), findsOneWidget);
    expect(find.text('마이 구독'), findsOneWidget);
    expect(find.text('좋아하는 팀 경기, 선수 솔랭 놓치지 않고 챙겨보세요'), findsOneWidget);
    expect(find.text('온보딩에서 선택한 팀, 선수가 자동으로 구독돼요.'), findsOneWidget);
    // 무대 — 목업 2장(화면·하단 네비)과 말풍선 2개(위젯).
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('1. 마이구독 페이지에서'), findsOneWidget);
    expect(find.text('2. 구독 설정 아이콘 클릭!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2장으로 넘기면 그 장의 설명이 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) =>
              GuideScreen(pages: [guidePage1(context), guidePage2(context)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('온보딩에서 선택한 팀, 선수가 자동으로 구독돼요.'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      find.text('응원하는 팀,선수가 더 있다면 마이구독 설정에서 언제든 추가할 수 있어요.'),
      findsOneWidget,
    );
    expect(find.text('2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('6장까지 순서대로 넘어가고 각 장의 설명이 바뀐다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) => GuideScreen(
            pages: [
              guidePage1(context),
              guidePage2(context),
              guidePage3(context),
              guidePage4(context),
              guidePage5(context),
              guidePage6(context),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('마이 구독'), findsOneWidget);
    // 진행 표시는 전체 장 수가 아니라 섹션 안에서의 순번/장수다 — '마이
    // 구독'은 2장, '마이 페이지'는 3장.
    expect(find.text('1/2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('마이 페이지'), findsOneWidget);
    expect(find.text('경기, 솔랭 알림을 커스텀 해보세요'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    // 4장은 3장과 문구가 같고 무대만 다르다.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    expect(find.text('마이 페이지'), findsOneWidget);

    // 5장은 같은 섹션이지만 문구가 다르다.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('와딩 사용자 편의성 맞춤 설정'), findsOneWidget);

    // 6장은 섹션이 한 장뿐이라 페이지 숫자('n/n')는 없지만, 점 진행바는
    // 전체 6장 기준으로 계속 그린다.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.byType(GuideProgressBar), findsOneWidget);
    expect(find.text('6/6'), findsNothing);
    expect(find.text('다양한 와딩 위젯 제공'), findsOneWidget);
    expect(
      find.text('(위 이미지는 연출된 이미지 입니다. 실제 적용 화면은 상이할 수 있습니다.)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('말풍선 꼬리가 시안이 가리키는 지점에 정확히 온다', (tester) async {
    // 말풍선 폭은 문구·글꼴에 따라 달라진다. 왼쪽 끝을 고정하면 그만큼 꼬리가
    // 대상에서 밀리므로, 꼬리 중심이 기준점에 오는지를 본다.
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final wScale =
        tester.getSize(find.byType(PageView)).width / guideDesignWidth;
    // 꼬리는 CustomPaint 로 그린다. 말풍선(Text)이 아니라 이쪽을 재야 한다 —
    // 꼬리는 말풍선 폭의 tailAlignment 지점에 붙지 가운데가 아니다.
    final callouts = find.byType(GuideCallout);
    final tailCenters = <double>[];
    for (var i = 0; i < callouts.evaluate().length; i++) {
      final tail = find.descendant(
        of: callouts.at(i),
        matching: find.byType(CustomPaint),
      );
      tailCenters.add(tester.getRect(tail.first).center.dx / wScale);
    }
    tailCenters.sort();

    // 시안이 가리키는 지점 — 마이구독 탭(244), 구독 설정 아이콘(295).
    expect(tailCenters, hasLength(2));
    expect(tailCenters[0], closeTo(244, 2));
    expect(tailCenters[1], closeTo(295, 2));
  });

  testWidgets('영어 로케일에서는 말풍선 문구도 영어로 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => GuideScreen(pages: [guidePage1(context)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 말풍선을 SVG 로 두면 여기가 한국어로 남는다 — 위젯으로 그리는 이유.
    expect(find.text('1. On the My Subscription page'), findsOneWidget);
    expect(find.text('2. Tap the settings icon!'), findsOneWidget);
    expect(find.text('1. 마이구독 페이지에서'), findsNothing);
    // 헤더·하단 패널도 함께 영어여야 한다.
    expect(find.text('Exit guide'), findsOneWidget);
    expect(find.text('My Subscription'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('가이드가 쓰는 에셋이 모두 번들에 실려 있다', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final asset in const [
      'assets/images/guide/guide-1.png',
      'assets/images/guide/guide-1-2.png',
      'assets/images/guide/guide-2.png',
      'assets/images/guide/guide-3.png',
      'assets/images/guide/guide-3-2.png',
      'assets/images/guide/guide-4.png',
      'assets/images/guide/guide-4-2.png',
      'assets/images/guide/guide-5.png',
      'assets/images/guide/guide-5-2.png',
      'assets/images/guide/guide-5-3.png',
      'assets/images/guide/guide-6.png',
      'assets/icons/empty-stars.svg',
      'assets/icons/user.svg',
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  testWidgets('목업 이미지에 3x 변형이 등록돼 있다', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final name in const [
      'guide-1.png',
      'guide-1-2.png',
      'guide-2.png',
      'guide-3.png',
      'guide-3-2.png',
      'guide-4.png',
      'guide-4-2.png',
      'guide-5.png',
      'guide-5-2.png',
      'guide-5-3.png',
      'guide-6.png',
    ]) {
      // 1x 만 있으면 2~3x 기기에서 확대돼 흐려진다. Flutter 가 배율에 맞는
      // 파일을 고를 수 있도록 3.0x/ 변형이 함께 실려 있어야 한다.
      final variants =
          manifest.getAssetVariants('assets/images/guide/$name') ?? [];
      expect(
        variants.any((v) => v.targetDevicePixelRatio == 3.0),
        isTrue,
        reason: '$name 에 3x 변형이 없다',
      );
    }
  });

  testWidgets('진행 표시가 현재 장을 가리킨다', (tester) async {
    await tester.pumpWidget(_host(pages: 2));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(GuideProgressBar), findsOneWidget);
  });

  testWidgets('스와이프하면 다음 장으로 넘어간다', (tester) async {
    // 진행 표시가 섹션 안 순번을 쓰므로, 실제로 다른 섹션 순번을 가진
    // 두 장으로 넘어가는지 확인하려면 같은 장을 복제하면 안 된다.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) =>
              GuideScreen(pages: [guidePage1(context), guidePage2(context)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('어떤 기기 높이에서도 무대:패널이 시안 비율(547:265)로 나뉜다', (tester) async {
    // 시안(812)보다 짧은 기기, 시안, 더 긴 기기, 태블릿.
    for (final size in const [
      Size(320, 568), // iPhone SE
      Size(375, 812), // 시안
      Size(430, 932), // iPhone Pro Max
      Size(768, 1024), // 태블릿
    ]) {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      // 무대(PageView) 높이가 곧 화면에서 패널을 뺀 몫이다.
      // 안전영역이 없는 테스트 환경이라 화면 전체가 시안 812 에 대응한다.
      final stageHeight = tester.getSize(find.byType(PageView)).height;
      final expected =
          size.height *
          guideStageDesignHeight /
          (guideStageDesignHeight + guidePanelDesignHeight);
      expect(
        stageHeight,
        closeTo(expected, 0.5),
        reason: '$size 에서 무대 높이가 시안 비율과 다르다',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('홈 인디케이터가 패널 안쪽을 먹지 않는다', (tester) async {
    const size = Size(393, 852); // iPhone 15
    const bottomInset = 34.0; // 홈 인디케이터
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            padding: EdgeInsets.only(top: 47, bottom: bottomInset),
          ),
          child: Builder(
            builder: (context) => GuideScreen(pages: [guidePage1(context)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panelHeight =
        size.height - tester.getSize(find.byType(PageView)).height;
    // 인디케이터를 뺀 '콘텐츠가 실제로 쓰는' 높이가 시안(265)에 준해야 한다.
    // 화면 전체에 비율을 곱하면 여기가 244 로 줄어 설명이 눌린다.
    expect(panelHeight - bottomInset, greaterThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면에서도 오버플로가 나지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('가이드 종료하기를 누르면 닫힌다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      GuideScreen(pages: [guidePage1(context)]),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('마이 구독'), findsOneWidget);

    await tester.tap(find.text('가이드 종료하기'));
    await tester.pumpAndSettle();

    expect(find.text('마이 구독'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
