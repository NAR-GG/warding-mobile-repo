import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 점선 테두리를 두른 상자.
///
/// Flutter 의 [Border] 는 점선을 지원하지 않고, 외부 패키지(dotted_border 등)를
/// 들이지 않기로 해서 [CustomPainter] 로 직접 그린다. 홈의 "아직 없음·누를 수
/// 없음"을 나타내는 자리(구독 0명 빈 카드, 순위표의 준비 중 리그 칩, 쇼츠 빈
/// 박스, 오늘 경기 "일정 전체" 카드)가 이 위젯 하나를 같이 쓴다.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color = AppColors.narLine2,
    this.radius = 0,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
    this.circle = false,
  });

  final Widget child;
  final Color color;

  /// 모서리 반경. [circle] 이면 무시한다.
  final double radius;
  final double strokeWidth;

  /// 점선 한 칸 길이와 칸 사이 간격(논리 픽셀).
  final double dash;
  final double gap;

  /// true 면 상자에 내접하는 원(타원)으로 그린다 — 빈 프로필 원 등.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
        circle: circle,
      ),
      child: child,
    );
  }
}

/// [DashedBorder] 의 페인터. 테두리 경로를 [PathMetric] 으로 따라가며
/// [dash] 만큼 그리고 [gap] 만큼 건너뛴다.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
    this.circle = false,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // 선 두께의 절반만큼 안으로 들여 그려야 바깥쪽 절반이 잘리지 않는다.
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final outline = Path();
    if (circle) {
      outline.addOval(rect);
    } else {
      outline.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final dashed = Path();
    for (final PathMetric metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap ||
      oldDelegate.circle != circle;
}
