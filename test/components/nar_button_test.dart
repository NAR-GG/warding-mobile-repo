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
    expect(subscribeSize.width, 64);
  });
}
