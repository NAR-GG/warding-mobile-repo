import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 별점 표시 (읽기 전용). [rating] 값(0~[maxStars])에 따라 별 5개를 채운다.
///
/// 반 별은 half-star.svg 의 `<mask>` 가 flutter_svg 에서 반투명하게 뭉개져
/// 탁해 보이는 문제가 있어, 마스크 없이 star.svg 하나만 써서
/// "회색 빈 별 위에 노란 별을 채움 비율만큼 좌측에서 클립해 덮는" 방식으로 그린다.
/// (시안의 Rectangle 143(회색)+144(노랑) 오버레이와 같은 원리.)
class NarStarRating extends StatelessWidget {
  const NarStarRating({
    super.key,
    required this.rating,
    this.maxStars = 5,
    this.starSize = 14,
    this.gap = 4,
    this.scale = 1,
  });

  final double rating;
  final int maxStars;
  final double starSize;
  final double gap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final size = starSize * scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < maxStars; i++) ...[
          if (i > 0) SizedBox(width: gap * scale),
          // 현재 별의 채움 비율: 1=꽉, 0.5=반, 0=빈.
          _Star(fraction: (rating - i).clamp(0.0, 1.0), size: size),
        ],
      ],
    );
  }
}

/// 별 한 개. 회색 빈 별 위에 노란 별을 [fraction] 만큼 좌측 클립해 덮는다.
class _Star extends StatelessWidget {
  const _Star({required this.fraction, required this.size});

  /// 0~1 채움 비율.
  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emptyStar = SvgPicture.asset(
      'assets/icons/star.svg',
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(
        AppColors.narLine2,
        BlendMode.srcIn,
      ),
    );
    if (fraction <= 0) return emptyStar;

    final fullStar = SvgPicture.asset(
      'assets/icons/star.svg',
      width: size,
      height: size,
    );
    if (fraction >= 1) return fullStar;

    // 부분 채움: 회색 별 위에 노란 별을 좌측 [fraction] 폭만큼만 보이도록 클립.
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
