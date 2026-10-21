import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/analytics_events.dart';
import 'package:warding/util/analytics_route_observer.dart';
import 'package:warding/util/tab_route.dart';

/// [AnalyticsRouteObserver] 가 `page_view` 를 **언제** 보내는지 검증한다.
///
/// `Analytics.track` 은 디버그·테스트에서 조용히 무시되므로(토큰 없음) 실제
/// 전송은 확인할 수 없다. 대신 observer 가 라우트를 화면으로 인정하는지를
/// [AnalyticsRouteObserver.currentPage] 로 본다 — `_track` 이 돌면 그 값이
/// 바뀌고, 무시하면 그대로다.
void main() {
  late AnalyticsRouteObserver observer;

  setUp(() => observer = AnalyticsRouteObserver());

  /// observer 가 붙은 Navigator 를 띄운다.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const SizedBox.shrink(),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('이름 있는 라우트를 push 하면 그 화면으로 기록한다', (tester) async {
    await pumpApp(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    nav.push(analyticsRoute(AnalyticsPage.myPlayers, (_) => const SizedBox()));
    await tester.pumpAndSettle();

    expect(observer.currentPage, AnalyticsPage.myPlayers);
  });

  testWidgets('하위 화면을 닫으면 돌아간 화면으로 기록한다', (tester) async {
    await pumpApp(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    // 홈 → 내 선수 → 뒤로가기.
    nav.push(tabRoute(const SizedBox(), name: AnalyticsPage.home));
    await tester.pumpAndSettle();
    nav.push(analyticsRoute(AnalyticsPage.myPlayers, (_) => const SizedBox()));
    await tester.pumpAndSettle();
    expect(observer.currentPage, AnalyticsPage.myPlayers);

    nav.pop();
    await tester.pumpAndSettle();

    // 복귀도 진입이다 — 설계상 page_view 가 다시 발생해야 한다.
    expect(observer.currentPage, AnalyticsPage.home);
  });

  testWidgets('바텀시트를 닫아도 화면 기록은 그대로다', (tester) async {
    await pumpApp(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    nav.push(tabRoute(const SizedBox(), name: AnalyticsPage.matchList));
    await tester.pumpAndSettle();

    // 정렬 시트처럼 이름 없는 라우트. 닫을 때 복귀로 세면
    // page_view(match_list, prev_page=match_list) 자기 루프가 쌓인다.
    nav.push(
      ModalBottomSheetRoute<void>(
        builder: (_) => const SizedBox(),
        isScrollControlled: false,
      ),
    );
    await tester.pumpAndSettle();
    // 시트는 화면이 아니므로 진입으로도 세지 않는다.
    expect(observer.currentPage, AnalyticsPage.matchList);

    nav.pop();
    await tester.pumpAndSettle();

    expect(observer.currentPage, AnalyticsPage.matchList);
  });

  testWidgets('다이얼로그를 닫아도 화면 기록은 그대로다', (tester) async {
    await pumpApp(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    nav.push(tabRoute(const SizedBox(), name: AnalyticsPage.community));
    await tester.pumpAndSettle();

    nav.push(
      DialogRoute<void>(
        context: tester.element(find.byType(Navigator)),
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    nav.pop();
    await tester.pumpAndSettle();

    expect(observer.currentPage, AnalyticsPage.community);
  });

  testWidgets('탭 전환(pushReplacement)도 기록한다', (tester) async {
    await pumpApp(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    nav.push(tabRoute(const SizedBox(), name: AnalyticsPage.home));
    await tester.pumpAndSettle();
    nav.pushReplacement(
      tabRoute(const SizedBox(), name: AnalyticsPage.community),
    );
    await tester.pumpAndSettle();

    expect(observer.currentPage, AnalyticsPage.community);
  });

  testWidgets('이름 없는 라우트는 진입으로 세지 않는다', (tester) async {
    await pumpApp(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));

    nav.push(tabRoute(const SizedBox(), name: AnalyticsPage.schedule));
    await tester.pumpAndSettle();
    nav.push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();

    expect(observer.currentPage, AnalyticsPage.schedule);
  });

  test('overridePrevPage 는 다음 기록의 prev_page 기준을 바꾼다', () {
    observer.overridePrevPage(AnalyticsPage.login);
    expect(observer.currentPage, AnalyticsPage.login);
    observer.overridePrevPage(null);
    expect(observer.currentPage, isNull);
  });
}
