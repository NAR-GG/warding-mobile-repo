import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 앱 공용 안내 배너.
///
/// 좌측 아이콘 + 안내 문구를 가로로 배치한 그라데이션 배너.
/// padding 10/16, gap 8, 높이 44, 기본 배경은 [AppColors.narRatingBannerBg].
///
/// - [icon] : 좌측 아이콘 위젯(보통 24×24 [SvgPicture]).
/// - [text] : 안내 문구.
/// - [onTap] : 탭 콜백. null 이면 탭 비활성.
/// - [onClose] : 우측 ✕ 탭 콜백. null 이면 ✕ 미표시.
/// - [gradient] : 배경 그라데이션. 기본값은 평점 배너 그라데이션.
///
/// 예) 세트 종료 평점 안내, 마이페이지 응원팀 설정 안내, 캘린더 공지 배너 등.
class NarBanner extends StatelessWidget {
  const NarBanner({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.onClose,
    this.gradient = AppColors.narRatingBannerBg,
    this.scale = 1,
  });

  final Widget icon;
  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final Gradient gradient;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44 * scale,
        padding: EdgeInsets.symmetric(
          vertical: 10 * scale,
          horizontal: 16 * scale,
        ),
        decoration: BoxDecoration(gradient: gradient),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            SizedBox(width: 8 * scale),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  fontSize: 14 * scale,
                  height: 1.55,
                  color: AppColors.narText,
                ),
              ),
            ),
            if (onClose != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Padding(
                  padding: EdgeInsets.only(left: 8 * scale),
                  child: Icon(
                    Icons.close,
                    size: 18 * scale,
                    color: AppColors.narText2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
