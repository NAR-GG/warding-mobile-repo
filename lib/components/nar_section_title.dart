import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 공용 섹션 제목 — 굵은 제목(17/w700) + 옆에 회색 부제, 우측에 "전체 보기" 링크.
///
/// 예) "월즈 성적  3경기 · 2승 1패", "순위표  2026 · 스위스 스테이지  전체 경기 >".
///
/// [subtitleSize] 는 홈 시안이 13, 선수 페이지가 12 라 호출부에서 정한다.
/// [padding] 은 선수 페이지처럼 섹션 사이 간격을 제목에 담아 둘 때 쓴다.
class NarSectionTitle extends StatelessWidget {
  const NarSectionTitle({
    super.key,
    required this.title,
    required this.scale,
    this.subtitle,
    this.subtitleSize = 13,
    this.trailingLabel,
    this.onTapTrailing,
    this.padding,
  });

  final String title;
  final double scale;

  /// 제목 옆에 붙는 회색 부제. null 이면 제목만.
  final String? subtitle;

  /// 부제 폰트 크기(기본 13 — 홈 시안).
  final double subtitleSize;

  /// 우측 링크 라벨. null 이면 링크 없음.
  final String? trailingLabel;
  final VoidCallback? onTapTrailing;

  /// 제목 블록 바깥 여백. null 이면 여백 없음.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title),
                if (subtitle != null)
                  TextSpan(
                    text: '  $subtitle',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: subtitleSize * scale,
                      color: AppColors.narText2,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 17 * scale,
              color: AppColors.narText,
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
                    fontSize: 14 * scale,
                    color: AppColors.narText2,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18 * scale,
                  color: AppColors.narText2,
                ),
              ],
            ),
          ),
      ],
    );
    return padding == null ? row : Padding(padding: padding!, child: row);
  }
}
