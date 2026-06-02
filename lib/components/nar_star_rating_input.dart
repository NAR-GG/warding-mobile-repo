import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 인터랙티브 별점 입력 (공용).
///
/// 별 위를 탭하거나 가로로 드래그하면 손가락 위치까지 채워진다. 0.5 단위 지원 —
/// 별의 왼쪽 절반은 0.5, 오른쪽 절반은 1.0. 채움은 full-star.svg(노랑) 위에
/// empty-star.svg(회색)를 [NarStarRating] 과 같은 좌측 클립 방식으로 그린다.
/// 읽기 전용 표시는 [NarStarRating] 을 쓴다.
class NarStarRatingInput extends StatelessWidget {
  const NarStarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.maxStars = 5,
    this.starSize = 32,
    this.gap = 4,
    this.scale = 1,
  });

  /// 현재 평점(0~[maxStars], 0.5 단위). 0이면 모두 빈 별.
  final double rating;

  /// 탭·드래그로 바뀐 평점(0.5~[maxStars])으로 호출.
  final ValueChanged<double> onChanged;

  final int maxStars;
  final double starSize;
  final double gap;
  final double scale;

  /// 로컬 x좌표 → 0.5 단위 평점. 별 왼쪽 절반=+0.5, 오른쪽 절반(과 gap)=+1.0.
  void _updateFromDx(double dx, double size, double g) {
    final unit = size + g;
    final clamped = dx.clamp(0.0, maxStars * unit);
    final index = (clamped / unit).floor().clamp(0, maxStars - 1);
    final within = clamped - index * unit;
    final value = (within < size / 2 ? index + 0.5 : index + 1.0).clamp(
      0.5,
      maxStars.toDouble(),
    );
    if (value != rating) onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final size = starSize * scale;
    final g = gap * scale;
    final totalWidth = maxStars * size + (maxStars - 1) * g;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _updateFromDx(d.localPosition.dx, size, g),
      onHorizontalDragStart: (d) => _updateFromDx(d.localPosition.dx, size, g),
      onHorizontalDragUpdate: (d) => _updateFromDx(d.localPosition.dx, size, g),
      child: SizedBox(
        width: totalWidth,
        height: size,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < maxStars; i++) ...[
              if (i > 0) SizedBox(width: g),
              _Star(fraction: (rating - i).clamp(0.0, 1.0), size: size),
            ],
          ],
        ),
      ),
    );
  }
}

/// 별 한 개. 빈 별 위에 채운 별을 [fraction] 만큼 좌측 클립해 덮는다.
class _Star extends StatelessWidget {
  const _Star({required this.fraction, required this.size});

  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emptyStar = SvgPicture.asset(
      'assets/icons/empty-star.svg',
      width: size,
      height: size,
    );
    if (fraction <= 0) return emptyStar;

    final fullStar = SvgPicture.asset(
      'assets/icons/full-star.svg',
      width: size,
      height: size,
    );
    if (fraction >= 1) return fullStar;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          emptyStar,
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: fullStar,
            ),
          ),
        ],
      ),
    );
  }
}
