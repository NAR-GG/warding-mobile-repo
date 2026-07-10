import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_button.dart';

void main() {
  testWidgets('구독/구독중 버튼은 텍스트 길이가 달라도 동일한 폭을 가진다', (
    WidgetTester tester,
  ) async {
    Future<Size> pumpAndGetSize(String label, NarButtonVariant variant) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: NarButton(label: label, variant: variant)),
          ),
        ),
      );
      return tester.getSize(find.byType(NarButton));
    }

    final subscribeSize = await pumpAndGetSize('구독', NarButtonVariant.subscribe);
    final subscribedSize = await pumpAndGetSize(
      '구독중',
      NarButtonVariant.subscribed,
    );

    expect(subscribeSize.width, subscribedSize.width);
  });

  testWidgets('구독중 라벨은 한 줄로 표시되고 버튼 밖으로 줄바꿈되지 않는다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NarButton(
              label: '구독중',
              variant: NarButtonVariant.subscribed,
            ),
          ),
        ),
      ),
    );

    final textSize = tester.getSize(find.text('구독중'));
    // 한 줄 높이(폰트 14, line-height 1) 근처여야 한다. 줄바꿈되면 2배 가까이 커진다.
    expect(textSize.height, lessThan(20));
  });
}
