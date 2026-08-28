import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_detail_header.dart';

/// 헤더 높이는 `34 * scale` 로 고정이다. 가운데 제목에 제약이 없으면 긴 제목이
/// 두 줄로 접히면서 그 상자를 넘어 위아래로 삐져나온다 — 커뮤니티 게시판 이름이
/// 'Hanwha Life Esports 게시판' 이 되면서 실제로 그렇게 깨졌다.
void main() {
  // 테스트 표면은 800px 라 그대로 두면 긴 제목도 한 줄에 들어가 버린다.
  // 실제 기기 폭으로 좁혀야 줄바꿈이 재현된다.
  Widget wrap(Widget child, {double width = 375}) => MediaQuery(
    data: MediaQueryData(size: Size(width, 800)),
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  /// 시안 기준 헤더 슬롯 높이.
  const slotHeight = 34.0;

  testWidgets('긴 제목이 한 줄로 줄어들어 헤더 높이를 넘지 않는다', (tester) async {
    const trailingKey = Key('trailing');

    await tester.pumpWidget(
      wrap(
        const NarDetailHeader(
          title: 'Hanwha Life Esports 게시판입니다 아주 아주 긴 제목',
          trailing: SizedBox(key: trailingKey, width: 18, height: 18),
        ),
      ),
    );

    final title = tester.getRect(find.textContaining('Hanwha'));
    expect(title.height, lessThanOrEqualTo(slotHeight));

    // 우측 아이콘 위로도 넘어가지 않는다.
    expect(
      title.right,
      lessThanOrEqualTo(tester.getRect(find.byKey(trailingKey)).left),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px 에서도 한 줄로 유지된다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const NarDetailHeader(title: 'Hanwha Life Esports 게시판'),
        width: 320,
      ),
    );

    expect(
      tester.getRect(find.textContaining('Hanwha')).height,
      lessThanOrEqualTo(slotHeight),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('짧은 제목은 가운데 그대로', (tester) async {
    await tester.pumpWidget(wrap(const NarDetailHeader(title: 'T1 게시판')));

    final title = tester.getRect(find.text('T1 게시판'));
    expect(title.center.dx, closeTo(375 / 2, 1));
  });
}
