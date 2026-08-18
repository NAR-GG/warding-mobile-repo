import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 말풍선 꼬리가 붙는 방향.
enum GuideCalloutTail {
  /// 꼬리가 말풍선 위쪽 — 가리키는 대상이 말풍선보다 위에 있을 때.
  up,

  /// 꼬리가 말풍선 아래쪽 — 가리키는 대상이 말풍선보다 아래에 있을 때.
  down,
}

/// 가이드 무대에서 앱 화면의 한 지점을 가리키는 설명 말풍선.
///
/// [Stack] 의 자식으로 쓴다(내부에서 [Positioned] 를 그린다).
///
/// **꼬리 끝이 기준점이다.** 문구를 [Text] 로 그리므로 로케일·글꼴에 따라
/// 말풍선 폭이 달라지는데, 왼쪽 끝을 고정하면 그만큼 꼬리가 대상에서
/// 밀려난다. 그래서 위치를 [tailCenterX] 로 받아 꼬리를 거기에 맞추고,
/// 말풍선은 그 주위로 자란다.
///
/// 문구를 [Text] 로 그리는 이유는 다국어다 — 디자인 SVG 는 글자까지 path 로
/// 구워져 있어 영어 로케일에서도 한국어가 그대로 남는다.
class GuideCallout extends StatelessWidget {
  const GuideCallout({
    super.key,
    required this.text,
    required this.tail,
    required this.tailCenterX,
    required this.tailTipY,
    required this.tailAlignment,
    required this.wScale,
    required this.hScale,
    this.horizontalPadding = 8,
  });

  final String text;
  final GuideCalloutTail tail;

  /// 꼬리 끝의 가로 위치(시안 좌표). 가리키는 대상의 중심.
  final double tailCenterX;

  /// 꼬리 끝의 세로 위치(시안 좌표). 대상에 닿는 지점.
  final double tailTipY;

  /// 말풍선 폭에서 꼬리가 붙는 지점(0=왼쪽 끝, 0.5=가운데, 1=오른쪽 끝).
  ///
  /// 시안은 이 값이 장마다 다르다(0.10 ~ 0.92). 가운데로 통일하면 말풍선이
  /// 대상 반대편으로 쏠려 화면 밖으로 밀려나거나 목업을 가린다.
  final double tailAlignment;

  /// 좌우 안쪽 여백(시안). 장마다 8 또는 16 이다.
  final double horizontalPadding;

  /// 가로·세로 환산 배율. 기기 화면비가 시안과 달라 따로 받는다.
  final double wScale;
  final double hScale;

  /// 시안 꼬리 크기.
  static const double tailWidth = 20;
  static const double tailHeight = 16.5;

  /// 시안 말풍선 높이.
  static const double bubbleHeight = 34;

  /// 꼬리가 말풍선 안으로 파고드는 깊이(시안).
  ///
  /// 시안 SVG 는 둘을 겹쳐 두었다(말풍선 끝 34, 꼬리 시작 28). 딱 붙이기만
  /// 하면 radius 10 의 둥근 모서리와 꼬리 밑변 사이에 틈이 생겨 이어 붙인
  /// 티가 난다.
  static const double tailOverlap = 6;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      height: bubbleHeight * wScale,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * wScale),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.narGuideCallout,
        borderRadius: BorderRadius.circular(10 * wScale),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
          fontSize: 14 * wScale,
          color: AppColors.narTextTertiary,
        ),
      ),
    );

    final tailWidget = CustomPaint(
      size: Size(tailWidth * wScale, tailHeight * wScale),
      painter: _TailPainter(pointsUp: tail == GuideCalloutTail.up),
    );

    final pointsUp = tail == GuideCalloutTail.up;
    // 꼬리가 말풍선에 파고드는 만큼 빼야 실제 차지하는 높이가 된다.
    final visibleTailHeight = (tailHeight - tailOverlap) * wScale;
    // 꼬리 끝에서 말풍선 반대편 끝까지의 높이. 세로 위치를 잡는 데 쓴다.
    final totalHeight = visibleTailHeight + bubbleHeight * wScale;

    // 꼬리 끝이 기준점([tailCenterX])에 오도록 말풍선을 건다.
    //
    // 말풍선 폭은 문구·글꼴에 따라 달라져 여기서 알 수 없으므로,
    // [FractionalTranslation] 으로 '자기 폭의 tailAlignment 배'만큼 왼쪽으로
    // 옮긴다. 그러면 폭이 얼마든 그 비율 지점이 기준점에 맞는다.
    return Positioned(
      left: tailCenterX * wScale,
      // 꼬리가 위면 끝이 위쪽이라 그 지점부터 아래로, 아래면 위로 쌓인다.
      top: pointsUp ? tailTipY * hScale : tailTipY * hScale - totalHeight,
      child: FractionalTranslation(
        translation: Offset(-tailAlignment, 0),
        // Stack 으로 두어 말풍선이 전체 폭을 정하고, 꼬리는 그 폭 안에서
        // [tailAlignment] 지점에 놓인다. Column + stretch 는 Positioned 아래서
        // 폭 제약이 없어 레이아웃이 깨진다.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 말풍선이 Stack 의 크기를 정한다. 꼬리 쪽에는 보이는 만큼만
            // 자리를 비워 둬, 그 아래로 꼬리가 파고들어 겹친다.
            Padding(
              padding: EdgeInsets.only(
                top: pointsUp ? visibleTailHeight : 0,
                bottom: pointsUp ? 0 : visibleTailHeight,
              ),
              child: bubble,
            ),
            // 꼬리. 말풍선보다 먼저 그려지도록 Stack 아래에 두면 폭을 못
            // 정하므로, 위에 얹되 겹치는 부분은 말풍선 색과 같아 티가 없다.
            Positioned(
              top: pointsUp ? 0 : null,
              bottom: pointsUp ? null : 0,
              left: 0,
              right: 0,
              // Transform 으로 꼬리를 옮긴다. Align 은 '남는 공간'을 비율로
              // 나눠서 꼬리 폭만큼 어긋난다 — 여기서는 꼬리 '중심'이 말풍선
              // 폭의 tailAlignment 지점에 정확히 와야 한다.
              child: LayoutBuilder(
                builder: (context, constraints) => Transform.translate(
                  offset: Offset(
                    constraints.maxWidth * tailAlignment -
                        tailWidth * wScale / 2,
                    0,
                  ),
                  child: Align(alignment: Alignment.topLeft, child: tailWidget),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 말풍선 꼬리 삼각형. 시안은 꼭짓점이 살짝 둥글다(radius 2).
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.pointsUp});

  /// true 면 꼭짓점이 위를 향한다(말풍선이 아래에 있음).
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    // 꼭짓점을 둥글리려면 획을 겹쳐 그린다 — fill 만으로는 각이 그대로 남는다.
    const radius = 2.0;
    final paint = Paint()
      ..color = AppColors.narGuideCallout
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.narGuideCallout
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 2
      ..strokeJoin = StrokeJoin.round;

    // 획 두께의 절반만큼 안쪽에서 그려야 전체 크기가 size 를 넘지 않는다.
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, radius)
        ..lineTo(size.width - radius, size.height - radius)
        ..lineTo(radius, size.height - radius);
    } else {
      path
        ..moveTo(radius, radius)
        ..lineTo(size.width - radius, radius)
        ..lineTo(size.width / 2, size.height - radius);
    }
    path.close();
    canvas
      ..drawPath(path, paint)
      ..drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) =>
      oldDelegate.pointsUp != pointsUp;
}
