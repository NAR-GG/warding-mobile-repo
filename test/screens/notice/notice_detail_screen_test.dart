import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:warding/l10n/app_localizations.dart';
import 'package:warding/model/notice.dart';
import 'package:warding/screens/notice/notice_detail_screen.dart';
import 'package:warding/util/api_client.dart' as api;

/// 광고 안내처럼 버튼 주소가 있는 공지는 하단에 고정 버튼이 뜨고, 일반 공지는
/// 화면이 그대로다. 버튼이 본문 마지막 줄을 가리지 않는 것도 함께 잠근다.
void main() {
  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ko'),
    home: child,
  );

  Notice notice({String? actionUrl}) => Notice(
    id: 7,
    title: '와딩 광고 안내',
    content: List.generate(40, (i) => '- 항목 $i').join('\n'),
    pinned: false,
    publishedAt: DateTime(2026, 10, 12, 18),
    actionUrl: actionUrl,
  );

  setUp(() {
    // 상세를 열면 조회수 +1 요청이 나간다 — 네트워크는 막아 둔다.
    api.setApiClientForTesting(MockClient((_) async => http.Response('', 204)));
  });

  tearDown(() => api.setApiClientForTesting(null));

  testWidgets('버튼 주소와 문구가 있으면 하단 고정 버튼이 뜬다', (tester) async {
    await tester.pumpWidget(
      host(
        NoticeDetailScreen(
          notice: notice(actionUrl: 'https://forms.gle/abc'),
          headerTitle: '광고 안내',
          actionLabel: '광고 신청하기',
        ),
      ),
    );

    expect(find.text('광고 신청하기'), findsOneWidget);
    expect(
      find.text('광고 안내'),
      findsOneWidget,
      reason: '헤더 타이틀은 공지사항이 아니라 전용 이름',
    );

    // 본문을 끝까지 내려도 버튼은 같은 자리에 있다.
    final before = tester.getTopLeft(find.text('광고 신청하기'));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -3000),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.text('광고 신청하기')), before);
  });

  testWidgets('마지막 줄이 버튼 아래에 가려지지 않는다', (tester) async {
    await tester.pumpWidget(
      host(
        NoticeDetailScreen(
          notice: notice(actionUrl: 'https://forms.gle/abc'),
          actionLabel: '광고 신청하기',
        ),
      ),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -5000),
    );
    await tester.pump();

    final lastLine = tester.getRect(find.textContaining('항목 39'));
    final button = tester.getRect(find.text('광고 신청하기'));
    expect(lastLine.bottom, lessThanOrEqualTo(button.top));
  });

  testWidgets('버튼 주소가 없으면 일반 공지처럼 버튼이 없다', (tester) async {
    await tester.pumpWidget(
      host(NoticeDetailScreen(notice: notice(), actionLabel: '광고 신청하기')),
    );

    expect(find.text('광고 신청하기'), findsNothing);
    expect(find.text('공지사항'), findsOneWidget);
  });

  test('actionUrl 은 공백이면 null 로 읽는다', () {
    expect(Notice.fromJson({'id': 1, 'actionUrl': '  '}).actionUrl, isNull);
    expect(Notice.fromJson({'id': 1}).actionUrl, isNull);
    expect(
      Notice.fromJson({
        'id': 1,
        'actionUrl': ' https://forms.gle/abc ',
      }).actionUrl,
      'https://forms.gle/abc',
    );
  });
  testWidgets('scroll: 이미지는 가로 스크롤 한 줄로 묶이고 캡션이 붙는다', (tester) async {
    final n = Notice(
      id: 8,
      title: '예시',
      content: [
        '![scroll:스플래시|200](https://x.test/a.png)',
        '',
        '![scroll:팝업|200](https://x.test/b.png)',
        '',
        '![scroll:배너|200](https://x.test/c.png)',
        '끝 문단',
      ].join('\n'),
      pinned: false,
      publishedAt: DateTime(2026, 10, 12),
    );
    await tester.pumpWidget(host(NoticeDetailScreen(notice: n)));

    expect(find.text('스플래시'), findsOneWidget);
    expect(find.text('팝업'), findsOneWidget);
    expect(find.text('배너'), findsOneWidget);
    expect(find.text('끝 문단'), findsOneWidget);
    final horizontal = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(horizontal, findsOneWidget);
  });
}
