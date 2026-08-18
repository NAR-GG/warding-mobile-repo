import 'package:flutter/material.dart';

/// 그림자가 파일에 구워진 목업 이미지 한 장.
///
/// 시안이 `filter: drop-shadow(4px 4px 12px …)` 를 준 이미지는 내보낼 때 그
/// 번짐까지 픽셀에 포함돼, 실제 파일이 시안 사각형보다 사방 [shadowMargin]
/// 만큼 크다. 시안 좌표는 그림자를 뺀 사각형 기준이므로, 위치를 그만큼 당기고
/// 크기를 키워 그려야 시안과 같은 자리에 온다.
///
/// 그림자는 이미 이미지에 있으므로 여기서 [BoxShadow] 를 덧붙이지 않는다 —
/// 덧붙이면 두 겹으로 보인다.
class GuideShadowedMock extends StatelessWidget {
  const GuideShadowedMock({
    super.key,
    required this.asset,
    required this.designWidth,
    required this.designHeight,
    required this.designLeft,
    required this.designTop,
    required this.wScale,
    required this.hScale,
  });

  /// 시안 기준 크기·위치(그림자를 뺀 사각형).
  final String asset;
  final double designWidth;
  final double designHeight;
  final double designLeft;
  final double designTop;

  /// 가로·세로 환산 배율. 기기 화면비가 시안과 달라 따로 받는다.
  final double wScale;
  final double hScale;

  /// 이미지에 포함된 그림자 여백(시안 단위). blur 12 기준.
  static const double shadowMargin = 12;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (designLeft - shadowMargin) * wScale,
      top: (designTop - shadowMargin) * hScale,
      child: Image.asset(
        asset,
        width: (designWidth + shadowMargin * 2) * wScale,
        height: (designHeight + shadowMargin * 2) * hScale,
        fit: BoxFit.fill,
      ),
    );
  }
}
