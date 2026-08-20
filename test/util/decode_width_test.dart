import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/app_image.dart';

/// 디코딩 폭 계산([decodeWidthFor]).
///
/// 이미지 메모리는 표시 크기가 아니라 디코딩 해상도로 정해지므로 줄일 값이
/// 있는데, 잘못 줄이면 화질이 깎인다. 특히 `BoxFit.cover` 는 칸을 채우려고
/// 원본을 확대하기 때문에 **칸 너비만 보고 자르면 안 된다** — 세로가 모자라
/// 늘어나는 만큼까지 쳐 줘야 흐려지지 않는다.
void main() {
  /// [dpr] 배율의 화면에서 계산값을 얻는다.
  Future<int> widthAt(
    WidgetTester tester, {
    required double dpr,
    required double boxWidth,
    required double boxHeight,
    int sourceWidth = 400,
    int sourceHeight = 600,
  }) async {
    late int result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(devicePixelRatio: dpr),
        child: Builder(
          builder: (context) {
            result = decodeWidthFor(
              context,
              boxWidth: boxWidth,
              boxHeight: boxHeight,
              sourceWidth: sourceWidth,
              sourceHeight: sourceHeight,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('정사각 칸 — 세로를 채우느라 확대되는 몫까지 친다', (tester) async {
    // 38 칸 @3x = 114px 필요. 원본 400×600 을 정사각에 cover 로 넣으면
    // 세로(600)가 기준이 아니라 **가로**가 모자라 확대된다... 가 아니라,
    // 세로 114 를 채우려면 600→114 (0.19배)면 되지만 그러면 가로가 76 뿐이라
    // 114 에 못 미친다. 그래서 가로 기준으로 잡혀 400×0.285 = 114 가 된다.
    final width = await widthAt(
      tester,
      dpr: 3,
      boxWidth: 38,
      boxHeight: 38,
    );

    expect(width, greaterThanOrEqualTo(114), reason: '3x 선명도를 잃으면 안 된다');
    expect(width, lessThan(200), reason: '줄이는 의미가 있어야 한다');
  });

  testWidgets('세로로 긴 칸 — 세로 기준으로 커진다', (tester) async {
    // 픽 카드 60×101 @3x = 180×303. 원본 비율(1.5)보다 칸이 길쭉해(1.68)
    // 세로를 채우는 쪽이 기준이 된다 → 303/600 = 0.505 → 가로 202.
    final width = await widthAt(
      tester,
      dpr: 3,
      boxWidth: 60,
      boxHeight: 101,
    );

    expect(
      width,
      greaterThanOrEqualTo(202),
      reason: '가로(180)만 보고 자르면 세로가 270 이라 303 에 못 미쳐 흐려진다',
    );
  });

  testWidgets('원본보다 크게 잡지 않는다 — 확대 저장은 메모리 낭비', (tester) async {
    final width = await widthAt(
      tester,
      dpr: 3,
      boxWidth: 400,
      boxHeight: 600,
    );

    expect(width, 400);
  });

  testWidgets('저배율 화면에서는 더 작게 잡는다', (tester) async {
    final at3x = await widthAt(tester, dpr: 3, boxWidth: 38, boxHeight: 38);
    final at2x = await widthAt(tester, dpr: 2, boxWidth: 38, boxHeight: 38);

    expect(at2x, lessThan(at3x));
  });
}
