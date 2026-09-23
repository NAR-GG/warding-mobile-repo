import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';

/// 홈 섹션 공용 헤더 — 제목(+옅은 부제) + 우측 "전체 보기" 링크.
///
/// 목업의 `sh(title, go, small)` 패턴 그대로: [trailingLabel] 이 없으면
/// 링크 없이 제목만 그린다.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.scale,
    this.subtitle,
    this.trailingLabel,
    this.onTapTrailing,
  });

  final String title;
  final double scale;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback? onTapTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 17 * scale,
                    color: AppColors.narText,
                  ),
                ),
                if (subtitle != null)
                  TextSpan(
                    text: '  $subtitle',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      fontSize: 12 * scale,
                      color: AppColors.narText2,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (trailingLabel != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapTrailing,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingLabel!,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13 * scale,
                    color: AppColors.narText2,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16 * scale,
                  color: AppColors.narText2,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
