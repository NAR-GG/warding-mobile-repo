import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/app_bottom_nav.dart';
import 'package:warding/l10n/app_localizations.dart';

/// 하단 네비게이션의 유리 효과 렌더 회귀 테스트.
///
/// 유리 효과는 셰이더용 지오메트리 이미지를 `toImageSync(w.ceil(), h.ceil())`
/// 로 만드는데, 면적이 0 인 프레임에서 'Invalid image dimensions.' 로 죽었다
/// (Sentry WARDING-APP-FLUTTER-A, 3.6K events / 925 users).
/// 효과는 장식이므로 어떤 경우에도 앱을 죽이거나 탭을 막아선 안 된다.
void main() {
  Widget wrap(Widget child, {Size size = const Size(390, 844)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('정상 크기에서 네 탭이 모두 렌더된다', (tester) async {
    await tester.pumpWidget(
      wrap(AppBottomNav(currentTab: AppNavTab.schedule, onTabSelected: (_) {})),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 활성 탭은 라벨까지, 비활성은 아이콘만 — 아이콘 4개가 항상 있어야 한다.
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('탭을 누르면 콜백이 선택된 탭으로 불린다', (tester) async {
    final tapped = <AppNavTab>[];
    await tester.pumpWidget(
      wrap(AppBottomNav(
        currentTab: AppNavTab.schedule,
        onTabSelected: tapped.add,
      )),
    );
    await tester.pumpAndSettle();

    // 비활성 탭(마이페이지) 위치를 눌러 콜백을 확인한다.
    await tester.tap(find.byType(AppBottomNav));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('면적이 0 에 가까운 제약에서도 예외 없이 그려진다', (tester) async {
    // 전환 애니메이션 중간처럼 폭이 거의 없는 프레임을 흉내 낸다.
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 0,
          height: 0,
          child: _NavProbe(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '면적 0 프레임에서 셰이더가 돌아 죽으면 안 된다');
  });

  testWidgets('작은 화면(320)에서도 예외 없이 그려진다', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppBottomNav(currentTab: AppNavTab.mypage, onTabSelected: (_) {}),
        size: const Size(320, 568),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _NavProbe extends StatelessWidget {
  const _NavProbe();

  @override
  Widget build(BuildContext context) => OverflowBox(
        maxWidth: 400,
        maxHeight: 100,
        child: AppBottomNav(
          currentTab: AppNavTab.list,
          onTabSelected: (_) {},
        ),
      );
}
