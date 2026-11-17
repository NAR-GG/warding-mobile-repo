import 'package:flutter/material.dart';

/// 시안의 인너 섀도우(CSS `box-shadow: inset ...`)를 그린다.
///
/// Flutter 의 [BoxShadow] 는 바깥 그림자만 지원해서 이 효과가 없다. 하단
/// 그라데이션으로 흉내 내는 방법이 흔히 쓰이지만, 그건 세로 방향 한 축만
/// 재현하는 근사다. 인너 섀도우는 사방 모서리에서 안쪽으로 번지기 때문에,
/// 오프셋이 세로뿐이어도 좌·우 가장자리에 옅은 띠가 생긴다 — 그라데이션에는
/// 그 띠가 없어 카드가 시안보다 평평해 보인다.
///
/// 그래서 CSS 와 같은 방식으로 직접 그린다.
///
/// 1. 도형 바깥을 [color] 로 채우고 안쪽은 비운다(= 구멍).
/// 2. 그 구멍을 [offset] 만큼 밀고 [blurRadius] 로 흐린다.
/// 3. 도형 안쪽으로만 잘라 낸다.
///
/// 결과적으로 밀려난 가장자리 쪽이 짙고 반대쪽은 옅게 깔린다.
///
/// [child] 위에 덮어 그리므로 [Stack] 의 마지막 레이어로 두거나 이 위젯으로
/// 감싸면 된다. 부모가 이미 클립하고 있어도 [borderRadius] 는 시안 값을 그대로
/// 넘긴다 — 그래야 모서리에서 그림자가 둥글게 말린다.
class InnerShadow extends StatelessWidget {
  const InnerShadow({
    super.key,
    required this.color,
    this.offset = Offset.zero,
    this.blurRadius = 0,
    this.spreadRadius = 0,
    this.borderRadius = BorderRadius.zero,
    this.child,
  });

  /// 그림자 색. 시안의 불투명도까지 포함한 값을 넘긴다
  /// (예: `AppColors.narDarkOpacity62`).
  final Color color;

  /// 시안의 Position X·Y. 아래로 번지게 하려면 음수 Y 를 준다(CSS 와 동일).
  final Offset offset;

  /// 시안의 Blur.
  final double blurRadius;

  /// 시안의 Spread. 구멍을 그만큼 좁혀 그림자를 두껍게 만든다.
  final double spreadRadius;

  /// 그림자를 가둘 도형의 모서리 반경.
  final BorderRadius borderRadius;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _InnerShadowPainter(
        color: color,
        offset: offset,
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _InnerShadowPainter extends CustomPainter {
  const _InnerShadowPainter({
    required this.color,
    required this.offset,
    required this.blurRadius,
    required this.spreadRadius,
    required this.borderRadius,
  });

  final Color color;
  final Offset offset;
  final double blurRadius;
  final double spreadRadius;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = borderRadius.toRRect(rect);

    // 도형 안쪽으로만 그린다 — 밖으로 번진 부분은 버린다.
    canvas.save();
    canvas.clipRRect(shape);

    // 그림자 판. 화면 밖까지 넉넉히 잡아, 구멍을 밀어도 반대편에 판이
    // 모자라 그림자가 끊기지 않게 한다.
    final slab = rect.inflate(blurRadius * 2 + offset.distance + 1);

    // 구멍 = 도형을 spread 만큼 좁히고 offset 만큼 민 것.
    final holeRect = shape.outerRect.deflate(spreadRadius).shift(offset);
    final hole = RRect.fromRectAndCorners(
      holeRect,
      topLeft: shape.tlRadius,
      topRight: shape.trRadius,
      bottomLeft: shape.blRadius,
      bottomRight: shape.brRadius,
    );

    // 판에서 구멍을 뚫은 나머지 = 그림자 모양.
    final shadow = Path.combine(
      PathOperation.difference,
      Path()..addRect(slab),
      Path()..addRRect(hole),
    );

    final paint = Paint()..color = color;
    if (blurRadius > 0) {
      // CSS 의 blur-radius 는 지름에 가깝고 sigma 는 반지름 쪽이라 절반으로 본다.
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius / 2);
    }
    canvas.drawPath(shadow, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter old) =>
      color != old.color ||
      offset != old.offset ||
      blurRadius != old.blurRadius ||
      spreadRadius != old.spreadRadius ||
      borderRadius != old.borderRadius;
}
