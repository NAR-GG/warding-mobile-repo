import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_toggle.dart';
import 'package:warding/repository/auth/auth_service.dart';
import 'package:warding/screens/match_list/component/match_alarm_sheet.dart';
import 'package:warding/screens/match_list/component/match_card.dart';

import '../../support/l10n_test_setup.dart';

void main() {
  setUp(() {
    // 벨 탭은 JWT 를 먼저 확인하고, 없으면 시트 대신 로그인 화면을 띄운다.
    // 저장소를 비워 두면 이 테스트가 로그인 화면을 검사하게 된다.
    FlutterSecureStorage.setMockInitialValues({'jwt': 'test-jwt'});
    AuthService.instance.resetJwtCacheForTesting();
  });

  testWidgets('경기 카드의 벨 아이콘을 탭하면 경기 알림 설정 시트가 뜬다', (
    WidgetTester tester,
  ) async {
    // 카드는 문구를 로케일에서 읽고, 폭이 좁으면 가로로 넘친다.
    await tester.pumpWidget(
      wrapWithL10n(
        const MatchCard(
          matchId: 'match-1',
          time: '18:00',
          label: '2026 LCK Spring',
          homeName: 'T1',
          awayName: 'GEN',
          homeScore: 1,
          awayScore: 0,
          isLive: true,
          liveSetLabel: 'SET 2 진행중',
          leagueInfo: 'LCK',
          // 이 테스트의 관심사는 벨 → 시트다. 스포방지 오버레이는 끈다.
          spoilerPreventionEnabled: false,
        ),
        size: const Size(390, 844),
      ),
    );

    final bellFinder = find.byKey(const Key('matchCardAlarmBell'));
    expect(bellFinder, findsOneWidget);

    await tester.tap(bellFinder);
    // 카드 스켈레톤이 계속 펄스해 pumpAndSettle 은 끝나지 않는다.
    // 시트가 열리는 시간만큼만 진행시킨다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('경기 알림 설정'), findsOneWidget);
    expect(find.text('T1'), findsWidgets);
    expect(find.text('GEN'), findsWidgets);
    expect(find.text('세트 시작 알림'), findsOneWidget);
    expect(find.text('세트 종료 알림'), findsOneWidget);
    expect(find.text('라이브 이벤트 알림'), findsOneWidget);

    // 라이브 이벤트가 기본 ON 이라 세부 항목 카드도 함께 펴져 있다.
    expect(find.text('킬'), findsOneWidget);
    expect(find.text('바론'), findsOneWidget);
    expect(find.text('드래곤'), findsOneWidget);
    expect(find.text('타워'), findsOneWidget);
    expect(find.text('억제기'), findsOneWidget);

    // 확인 버튼 탭 시 시트가 닫힌다.
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('경기 알림 설정'), findsNothing);
  });

  // ── 라이브 이벤트 세부 설정 ────────────────────────────────────────
  // 시트를 직접 띄운다 — 카드 경유는 스켈레톤 펄스 때문에 pumpAndSettle 이 안 끝난다.

  /// 시트를 열고 확인까지 눌러 결과를 받는다. [tapBeforeConfirm] 에서 토글을 만진다.
  Future<MatchAlarmResult?> openSheet(
    WidgetTester tester, {
    MatchAlarmResult? initial,
    Future<void> Function(WidgetTester t)? tapBeforeConfirm,
  }) async {
    MatchAlarmResult? result;
    late BuildContext ctx;
    await tester.pumpWidget(
      wrapWithL10n(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
        size: const Size(390, 844),
      ),
    );

    final future = showMatchAlarmSheet(
      context: ctx,
      homeName: 'T1',
      awayName: 'GEN',
      initial: initial,
    ).then((r) => result = r);

    await tester.pumpAndSettle();
    if (tapBeforeConfirm != null) await tapBeforeConfirm(tester);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await future;
    return result;
  }

  testWidgets('라이브 이벤트를 끄면 세부 항목 카드가 접힌다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      wrapWithL10n(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
        size: const Size(390, 844),
      ),
    );

    showMatchAlarmSheet(context: ctx, homeName: 'T1', awayName: 'GEN');
    await tester.pumpAndSettle();
    expect(find.text('킬'), findsOneWidget);

    // 라이브 이벤트 행의 토글을 끈다 — 토글 3개 중 세 번째.
    await tester.tap(find.byType(NarToggle).at(2));
    await tester.pumpAndSettle();

    expect(find.text('킬'), findsNothing);
    expect(find.text('억제기'), findsNothing);
    // 세트 시작/종료 행은 그대로 남는다.
    expect(find.text('세트 시작 알림'), findsOneWidget);
  });

  testWidgets('기본값 — 세부 5종이 모두 켜진 채로 반환된다', (tester) async {
    final result = await openSheet(tester);

    expect(result, isNotNull);
    expect(result!.liveEvent, isTrue);
    expect(result.kill, isTrue);
    expect(result.baron, isTrue);
    expect(result.dragon, isTrue);
    expect(result.tower, isTrue);
    expect(result.inhibitor, isTrue);
  });

  testWidgets('세부 항목을 끄면 그 항목만 false 로 반환된다', (tester) async {
    final result = await openSheet(
      tester,
      tapBeforeConfirm: (t) async {
        await t.tap(find.text('바론'));
        await t.pumpAndSettle();
        await t.tap(find.text('타워'));
        await t.pumpAndSettle();
      },
    );

    expect(result!.baron, isFalse);
    expect(result.tower, isFalse);
    // 나머지는 켜진 채다.
    expect(result.kill, isTrue);
    expect(result.dragon, isTrue);
    expect(result.inhibitor, isTrue);
  });

  testWidgets('initial 을 주면 그 값으로 열린다 (구독 수정)', (tester) async {
    const initial = (
      setStart: true,
      setEnd: false,
      liveEvent: true,
      kill: false,
      baron: true,
      dragon: false,
      tower: true,
      inhibitor: false,
    );

    final result = await openSheet(tester, initial: initial);

    // 아무것도 안 만졌으니 준 값이 그대로 나와야 한다.
    expect(result!.setEnd, isFalse);
    expect(result.kill, isFalse);
    expect(result.baron, isTrue);
    expect(result.dragon, isFalse);
    expect(result.tower, isTrue);
    expect(result.inhibitor, isFalse);
  });

  testWidgets('라이브 이벤트를 꺼도 고른 세부 조합은 결과에 남는다', (tester) async {
    final result = await openSheet(
      tester,
      tapBeforeConfirm: (t) async {
        // 드래곤을 끈 뒤 라이브 이벤트 자체를 끈다.
        await t.tap(find.text('드래곤'));
        await t.pumpAndSettle();
        await t.tap(find.byType(NarToggle).at(2));
        await t.pumpAndSettle();
      },
    );

    expect(result!.liveEvent, isFalse);
    // 카드가 접혀도 값은 보존된다 — 다시 켰을 때 조합이 살아 있어야 하므로.
    expect(result.dragon, isFalse);
    expect(result.kill, isTrue);
  });
}
