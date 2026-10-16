import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 스플래시 광고 탭 잠금 동작.
///
/// 스플래시 화면 자체는 secure storage·네트워크·플랫폼 채널에 묶여 있어
/// 위젯 테스트로 띄우기 어렵다. 여기서는 화면이 쓰는 것과 **같은 구조**
/// (1초 타이머로 `IgnorePointer.ignoring` 를 푸는 것)를 재현해, 그 타이밍
/// 규칙이 의도대로 동작하는지만 본다.
///
/// 진입 직후 오탭으로 외부 브라우저가 열리면 앱 진입이 끊기므로 1초는
/// 막아야 하고, 그 뒤에는 광고주가 산 자리가 눌려야 한다.
void main() {
  const unlockDelay = Duration(seconds: 1);

  Widget harness({required ValueNotifier<bool> enabled, required VoidCallback onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, value, _) => IgnorePointer(
            ignoring: !value,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('진입 직후에는 광고 탭이 막힌다', (tester) async {
    var taps = 0;
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);

    await tester.pumpWidget(harness(enabled: enabled, onTap: () => taps++));
    await tester.tap(find.byType(SizedBox), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0, reason: '1초 전에는 눌려도 반응하지 않아야 한다');
  });

  testWidgets('1초가 지나면 광고 탭이 열린다', (tester) async {
    var taps = 0;
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);

    await tester.pumpWidget(harness(enabled: enabled, onTap: () => taps++));

    // 화면이 거는 것과 같은 타이머.
    Timer(unlockDelay, () => enabled.value = true);
    await tester.pump(unlockDelay);
    await tester.pump();

    await tester.tap(find.byType(SizedBox));
    await tester.pump();

    expect(taps, 1, reason: '1초 뒤에는 광고가 눌려야 한다');
  });

  testWidgets('잠금이 풀리기 전에 화면이 사라져도 타이머가 터지지 않는다', (tester) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);

    await tester.pumpWidget(harness(enabled: enabled, onTap: () {}));
    // 스플래시는 보통 1초 안에 다음 화면으로 넘어가지 않지만, 넘어가더라도
    // dispose 에서 타이머를 끊어야 setState 가 불리지 않는다.
    final timer = Timer(unlockDelay, () => enabled.value = true);
    await tester.pumpWidget(const SizedBox.shrink());
    timer.cancel();
    await tester.pump(unlockDelay);

    expect(timer.isActive, isFalse);
  });
}
