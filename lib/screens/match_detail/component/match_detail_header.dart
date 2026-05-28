import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../components/nar_dropdown.dart';
import '../../../styles/app_colors.dart';

/// 경기 상세 페이지 헤더. 왼쪽 뒤로가기 + 가운데 '경기 상세' 타이틀 + 오른쪽 세트 드롭다운.
class MatchDetailHeader extends StatelessWidget {
  const MatchDetailHeader({
    super.key,
    this.onBack,
    required this.setLabel,
    this.onSetTap,
    this.scale = 1,
  });

  final VoidCallback? onBack;
  final String setLabel;
  final VoidCallback? onSetTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 18.5 * scale,
        left: 20 * scale,
        right: 20 * scale,
        bottom: 22 * scale,
      ),
      child: SizedBox(
        height: 34 * scale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                '경기 상세',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 18 * scale,
                  height: 21 / 18,
                  color: AppColors.narText,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  child: SvgPicture.asset(
                    'assets/icons/back.svg',
                    width: 24 * scale,
                    height: 24 * scale,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: NarDropdown(
                variant: NarDropdownVariant.round,
                value: setLabel,
                onTap: onSetTap,
                scale: scale,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
