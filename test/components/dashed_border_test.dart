import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/dashed_border.dart';
import 'package:warding/styles/app_colors.dart';

void main() {
  testWidgets('자식을 그대로 그리고 점선 페인터를 위에 얹는다', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: DashedBorder(
            radius: 10,
            child: SizedBox(width: 120, height: 40, child: Text('준비 중')),
          ),
        ),
      ),
    );

    expect(find.text('준비 중'), findsOneWidget);
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(DashedBorder),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = paint.foregroundPainter! as DashedBorderPainter;
    expect(painter.color, AppColors.narLine2);
    expect(painter.radius, 10);
    // 자식 크기를 바꾸지 않는다.
    expect(tester.getSize(find.byType(DashedBorder)), const Size(120, 40));
    expect(tester.takeException(), isNull);
  });

  test('값이 같으면 다시 그리지 않고 바뀌면 다시 그린다', () {
    const a = DashedBorderPainter(
      color: AppColors.narLine2,
      radius: 8,
      strokeWidth: 1,
      dash: 4,
      gap: 3,
    );
    const same = DashedBorderPainter(
      color: AppColors.narLine2,
      radius: 8,
      strokeWidth: 1,
      dash: 4,
      gap: 3,
    );
    const round = DashedBorderPainter(
      color: AppColors.narLine2,
      radius: 8,
      strokeWidth: 1,
      dash: 4,
      gap: 3,
      circle: true,
    );
    expect(a.shouldRepaint(same), isFalse);
    expect(a.shouldRepaint(round), isTrue);
  });
}
