import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/components/inner_shadow.dart';

/// 인너 섀도우.
///
/// Flutter 에는 인셋 그림자가 없어 하단 그라데이션으로 흉내 내기 쉬운데,
/// 그러면 세로 한 축만 재현돼 좌·우 가장자리의 옅은 띠가 빠진다. 여기서는
/// 그 띠까지 나오는지, 그리고 시안의 Y 오프셋 방향이 뒤집히지 않았는지를
/// 실제로 픽셀을 찍어 확인한다.
void main() {
  /// 흰 배경 위에 [shadow] 를 그린 뒤 픽셀을 읽는다.
  /// 그림자가 짙을수록 어두우므로, 밝기로 그림자 세기를 잰다.
  Future<ui.Image> render(WidgetTester tester, InnerShadow shadow) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: 60,
              height: 101,
              child: ColoredBox(color: const Color(0xFFFFFFFF), child: shadow),
            ),
          ),
        ),
      ),
    );
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).last,
        );
    return boundary.toImage();
  }

  /// (x, y) 픽셀의 밝기(0~255). 낮을수록 그림자가 짙다.
  Future<int> luminanceAt(ui.Image image, int x, int y) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (y * image.width + x) * 4;
    return data!.getUint8(offset);
  }

  const shadow = InnerShadow(
    color: Color(0x9E141517),
    offset: Offset(0, -32),
    blurRadius: 55,
  );

  testWidgets('Y 가 음수면 아래쪽이 짙다 — 시안의 -32 방향', (tester) async {
    final image = await render(tester, shadow);

    final top = await luminanceAt(image, 30, 4);
    final bottom = await luminanceAt(image, 30, 96);

    expect(
      bottom,
      lessThan(top),
      reason: '부호를 뒤집으면 위가 짙어져 시안과 반대가 된다',
    );
  });

  testWidgets('좌·우 가장자리가 같은 높이의 가운데보다 짙다', (tester) async {
    // 세로 그라데이션으로 흉내 내면 이 차이가 0 이 된다 — 인너 섀도우는
    // 사방에서 번지므로 가장자리에 띠가 생겨야 한다.
    final image = await render(tester, shadow);

    const y = 50;
    final left = await luminanceAt(image, 1, y);
    final center = await luminanceAt(image, 30, y);
    final right = await luminanceAt(image, 58, y);

    expect(left, lessThan(center), reason: '왼쪽 가장자리 띠가 없다');
    expect(right, lessThan(center), reason: '오른쪽 가장자리 띠가 없다');
  });

  testWidgets('그림자는 도형 밖으로 새지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 60,
            height: 101,
            child: InnerShadow(
              color: Color(0xFF000000),
              offset: Offset(0, -32),
              blurRadius: 55,
            ),
          ),
        ),
      ),
    );

    // 클립이 빠지면 판(slab)이 화면을 다 덮어 이 크기를 넘어선다.
    expect(tester.getSize(find.byType(InnerShadow)), const Size(60, 101));
  });

  testWidgets('child 를 그대로 그린다 — 위에 덮어씌운다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InnerShadow(
          color: Color(0x9E141517),
          child: Text('Faker', textDirection: TextDirection.ltr),
        ),
      ),
    );

    expect(find.text('Faker'), findsOneWidget);
  });
}
