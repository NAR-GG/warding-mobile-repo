import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/nar_button.dart';
import 'package:warding/l10n/app_localizations.dart';

import '../support/l10n_test_setup.dart';

void main() {
  testWidgets('구독/구독중 버튼은 텍스트 길이가 달라도 동일한 폭을 가진다', (
    WidgetTester tester,
  ) async {
    // 구독 버튼은 폭을 로케일 문구로 재므로 delegate 없이는 렌더되지 않는다.
    Future<Size> pumpAndGetSize(String label, NarButtonVariant variant) async {
      await tester.pumpWidget(
        wrapWithL10n(Center(child: NarButton(label: label, variant: variant))),
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
      wrapWithL10n(
        const Center(
          child: NarButton(
            label: '구독중',
            variant: NarButtonVariant.subscribed,
          ),
        ),
      ),
    );

    final textSize = tester.getSize(find.text('구독중'));
    // 한 줄 높이(폰트 14, line-height 1) 근처여야 한다. 줄바꿈되면 2배 가까이 커진다.
    expect(textSize.height, lessThan(20));
  });

  testWidgets('영어 로케일에서도 두 버튼의 폭이 같다', (WidgetTester tester) async {
    // 폭 기준을 '현재 로케일에서 더 긴 라벨'로 잡으므로 언어가 바뀌어도 유지돼야 한다.
    Future<Size> pumpAndGetSize(NarButtonVariant variant) async {
      late String label;
      await tester.pumpWidget(
        wrapWithL10n(
          Center(
            child: Builder(
              builder: (context) {
                final l = AppLocalizations.of(context)!;
                label = variant == NarButtonVariant.subscribe
                    ? l.subscribe
                    : l.subscribing;
                return NarButton(label: label, variant: variant);
              },
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      return tester.getSize(find.byType(NarButton));
    }

    final subscribe = await pumpAndGetSize(NarButtonVariant.subscribe);
    final subscribed = await pumpAndGetSize(NarButtonVariant.subscribed);

    expect(subscribe.width, subscribed.width);
  });
}
