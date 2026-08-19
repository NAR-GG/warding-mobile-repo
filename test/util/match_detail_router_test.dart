import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/config/app_globals.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/match_detail/match_detail_screen.dart';
import 'package:warding/util/match_detail_router.dart';

/// 경기 상세가 스택에 겹쳐 쌓이지 않는지.
///
/// 상세로 들어가는 길이 여럿이다 — 목록·일정·마이구독의 카드 탭과, 라이브
/// 위젯·다이나믹 아일랜드·푸시의 딥링크. 예전에는 라우터가 만든 라우트만
/// 기억해 두고 그걸로 중복을 판단해서, 목록에서 들어간 상세 위에 딥링크가
/// 한 장 더 쌓였다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(MatchDetailRouter.resetForTesting);

  Widget app() => MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: const Scaffold(body: Text('홈')),
      );

  int detailCount(WidgetTester t) =>
      t.widgetList(find.byType(MatchDetailScreen, skipOffstage: false)).length;

  /// 라우트 전환 애니메이션이 끝날 때까지 진행시킨다. 전환 도중에는 이전
  /// 화면이 아직 트리에 남아 있어 개수를 세면 실제보다 많게 나온다.
  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pumpAndSettle(const Duration(milliseconds: 50));
  }

  testWidgets('같은 경기를 연달아 열면 한 장만 유지한다', (tester) async {
    await tester.pumpWidget(app());

    unawaited(MatchDetailRouter.open(matchId: 'm-1'));
    await settle(tester);
    MatchDetailRouter.open(matchId: 'm-1', tabIndex: 2);
    await settle(tester);

    expect(detailCount(tester), 1);
  });

  testWidgets('목록에서 연 상세 위에 딥링크가 겹치지 않는다', (tester) async {
    await tester.pumpWidget(app());

    // 목록·일정·마이구독의 카드 탭도 이제 같은 창구를 쓴다.
    MatchDetailRouter.open(matchId: 'm-1', context: navigatorKey.currentContext);
    await settle(tester);
    expect(detailCount(tester), 1);

    // 그 상태에서 라이브 위젯/푸시 딥링크가 들어온다(context 없음).
    MatchDetailRouter.open(matchId: 'm-1', tabIndex: 1);
    await settle(tester);

    expect(
      detailCount(tester),
      1,
      reason: '예전에는 여기서 2장이 됐다 — 뒤로가기 하면 같은 화면이 또 나온다',
    );
  });

  testWidgets('다른 경기 딥링크는 이전 상세를 대체한다', (tester) async {
    await tester.pumpWidget(app());

    MatchDetailRouter.open(matchId: 'm-1', context: navigatorKey.currentContext);
    await settle(tester);
    MatchDetailRouter.open(matchId: 'm-2', tabIndex: 1);
    await settle(tester);

    expect(detailCount(tester), 1, reason: '상세 위에 상세가 겹치면 안 된다');
  });

  testWidgets('상세를 닫은 뒤 다시 열면 정상적으로 push 된다', (tester) async {
    await tester.pumpWidget(app());

    MatchDetailRouter.open(matchId: 'm-1');
    await settle(tester);
    navigatorKey.currentState!.pop();
    await settle(tester);
    expect(detailCount(tester), 0);

    MatchDetailRouter.open(matchId: 'm-1');
    await settle(tester);

    expect(detailCount(tester), 1);
  });

  testWidgets('matchId 가 비면 아무것도 열지 않는다', (tester) async {
    await tester.pumpWidget(app());

    unawaited(MatchDetailRouter.open(matchId: ''));
    await settle(tester);

    expect(detailCount(tester), 0);
  });
}
