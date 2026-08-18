import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/repository/auth/auth_service.dart';
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

    // 확인 버튼 탭 시 시트가 닫힌다.
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('경기 알림 설정'), findsNothing);
  });
}
