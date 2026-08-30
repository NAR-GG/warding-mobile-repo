import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/screens/schedule/component/schedule_header.dart';

/// 홈 헤더 우측이 벨까지 3개(벨+필터+팀)가 되면 320px 에서 빠듯하다 —
/// AppBottomNav 가 같은 이유로 overflow 났던 전례가 있어 세 폭을 잠근다
/// (커뮤니티 후속 문서 A절). 팀 아이콘은 네트워크 이미지라 테스트에서 못
/// 그리므로, 대신 월 라벨을 최장(2026.12)으로 두고 벨+필터 두 슬롯 + 미읽음
/// 배지(99+)로 우측 최악 폭을 만든다.
void main() {
  Widget wrap(Widget child, {required double width}) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(body: child),
      ),
    );
  }

  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('폭 $width 에서 벨·배지가 overflow 없이 들어간다', (tester) async {
      await tester.pumpWidget(
        wrap(
          ScheduleHeader(
            monthLabel: '2026.12',
            onFilterTap: () {},
            onBellTap: () {},
            unreadCount: 120, // '99+' 배지 최악 폭
          ),
          width: width,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '폭 $width 에서 RenderFlex overflow 가 나면 안 된다',
      );
    });
  }

  testWidgets('unreadCount 0 이면 배지가 없고, 벨 탭이 콜백을 부른다', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        ScheduleHeader(
          monthLabel: '2026.08',
          onFilterTap: () {},
          onBellTap: () => tapped++,
        ),
        width: 375,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('99+'), findsNothing);
    // 우측 첫 슬롯(벨) 탭.
    await tester.tap(find.byType(GestureDetector).at(1));
    expect(tapped, 1);
  });
}
