import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/screens/subscription/component/rank_end_notification.dart';

import '../../support/l10n_test_setup.dart';

/// 솔랭 종료 카드 문구. 서버 body 는 한국어 고정이라 쓰지 않고,
/// win·kda 원자값으로 로케일별로 다시 조립한다.
void main() {
  Widget card({
    bool? win,
    String? kda,
    int? durationSeconds,
    Locale locale = const Locale('ko'),
  }) {
    return wrapWithL10n(
      RankEndNotification(
        playerName: 'Pyosik',
        champion: '리 신',
        win: win,
        kda: kda,
        durationSeconds: durationSeconds,
        dateTime: '2026.08.19 16:27',
        relativeTime: '방금',
      ),
      locale: locale,
      size: const Size(375, 800),
    );
  }

  testWidgets('승리 + KDA — 시작 문구가 아니라 종료 문구를 쓴다', (tester) async {
    await tester.pumpWidget(card(win: true, kda: '18/1/11'));
    await tester.pumpAndSettle();

    expect(find.text('Pyosik 선수가 솔랭 한 판을 마쳤어요'), findsOneWidget);
    expect(find.text('리 신으로 승리 · 18/1/11'), findsOneWidget);
    // 시작 알림 문구가 새어나오면 안 된다.
    expect(find.textContaining('시작'), findsNothing);
  });

  testWidgets('경기 길이가 있으면 KDA 뒤에 분으로 덧붙인다', (tester) async {
    await tester.pumpWidget(card(win: true, kda: '18/1/11', durationSeconds: 1694));
    await tester.pumpAndSettle();
    expect(find.text('리 신으로 승리 · 18/1/11 · 28분'), findsOneWidget);
  });

  // 서버가 진행 중 매치·시계 이상이면 키를 빼고 보낸다. 구버전 서버도 키가 없다.
  testWidgets('경기 길이가 없으면 기존 문구 그대로', (tester) async {
    await tester.pumpWidget(card(win: true, kda: '18/1/11'));
    await tester.pumpAndSettle();
    expect(find.text('리 신으로 승리 · 18/1/11'), findsOneWidget);
  });

  // '0분' 은 정보가 아니라 오해를 만든다.
  testWidgets('1분 미만은 표기하지 않는다', (tester) async {
    await tester.pumpWidget(card(win: true, kda: '0/0/0', durationSeconds: 41));
    await tester.pumpAndSettle();
    expect(find.text('리 신으로 승리 · 0/0/0'), findsOneWidget);
    expect(find.textContaining('분'), findsNothing);
  });

  testWidgets('승패를 모르면 경기 길이도 붙이지 않는다', (tester) async {
    await tester.pumpWidget(card(durationSeconds: 1694));
    await tester.pumpAndSettle();
    expect(find.text('리 신 경기 종료'), findsOneWidget);
  });

  testWidgets('패배 문구', (tester) async {
    await tester.pumpWidget(card(win: false, kda: '2/9/3'));
    await tester.pumpAndSettle();
    expect(find.text('리 신으로 패배 · 2/9/3'), findsOneWidget);
  });

  testWidgets('KDA 없음 — 승패만 표기하고 · 뒤를 생략한다', (tester) async {
    await tester.pumpWidget(card(win: true));
    await tester.pumpAndSettle();
    expect(find.text('리 신으로 승리'), findsOneWidget);
  });

  testWidgets('결과를 못 읽은 경우 — 경기 종료만', (tester) async {
    await tester.pumpWidget(card());
    await tester.pumpAndSettle();
    expect(find.text('리 신 경기 종료'), findsOneWidget);
  });

  // 챔피언명 영문화·조사 생략은 위젯 로케일이 아니라 앱 전역 [AppLanguage] 를 본다
  // (RankStartNotification 과 동일). 여기선 en 문구 골격만 확인한다.
  testWidgets('영어 로케일 — 서버 한국어 body 대신 en 문구를 조립한다', (tester) async {
    await tester.pumpWidget(
      card(win: true, kda: '18/1/11', locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pyosik finished a solo queue game'), findsOneWidget);
    expect(find.textContaining('Win with'), findsOneWidget);
    expect(find.textContaining('· 18/1/11'), findsOneWidget);
  });
}
