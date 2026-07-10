import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/scroll_to_top_button.dart';

void main() {
  Widget buildApp(ScrollController controller) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: controller,
              itemCount: 100,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('item $i')),
            ),
            ScrollToTopButton(scrollController: controller, showAfter: 300),
          ],
        ),
      ),
    );
  }

  testWidgets('300 이상 스크롤해야 나타나고, 탭하면 맨 위로 스크롤한다', (
    WidgetTester tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildApp(controller));

    // 초기에는 숨김(투명) 상태.
    var opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0);

    controller.jumpTo(500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1);

    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
  });
}
