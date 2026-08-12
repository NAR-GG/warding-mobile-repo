import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// 설정 상세 화면 공용 헤더 (padding 10, 높이 46).
///
/// 좌측 chevron-left 뒤로가기(24) + gap 16 + 타이틀(SF Pro Display 18/700).
/// 공용 [NarDetailHeader] 와 폰트(SF Pro Display)·여백이 달라 따로 둔다.
/// 마이 구독 설정·경기리스트 설정 등 '화면 설정' 하위 화면이 함께 쓴다.
class NarSettingHeader extends StatelessWidget {
  const NarSettingHeader({
    super.key,
    required this.title,
    required this.scale,
    this.onBack,
  });

  final String title;
  final double scale;

  /// 뒤로가기 탭 콜백. null 이면 `Navigator.maybePop` 호출.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(10 * scale),
      child: SizedBox(
        height: 26 * scale,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: SvgPicture.asset(
                'assets/icons/chevron-left.svg',
                width: 24 * scale,
                height: 24 * scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narText,
                  BlendMode.srcIn,
                ),
              ),
            ),
            SizedBox(width: 16 * scale),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w700,
                  fontSize: 18 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
