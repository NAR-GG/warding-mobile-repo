import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// [NarDropdown] 의 모양 변종.
enum NarDropdownVariant {
  /// 사각형. 높이 38·radius 10·narBgSecondary 배경. 너비는 부모를 따른다.
  rect,

  /// 알약형. 높이 34·pill·narBgTertiary 배경. 너비는 내용에 맞춰 줄어든다.
  round,
}

/// 단순 드롭다운 트리거 버튼. 좌측에 선택값 텍스트, 우측에 chevron-down.
///
/// 옵션 리스트 표시는 호출자가 [onTap] 안에서 BottomSheet 등으로 처리한다.
class NarDropdown extends StatelessWidget {
  const NarDropdown({
    super.key,
    required this.value,
    this.onTap,
    this.scale = 1,
    this.variant = NarDropdownVariant.rect,
  });

  final String value;
  final VoidCallback? onTap;
  final double scale;
  final NarDropdownVariant variant;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: variant == NarDropdownVariant.round
          ? _buildRound()
          : _buildRect(),
    );
  }

  Widget _buildRect() {
    return Container(
      height: 38 * scale,
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 22 / 14, // 155%
                color: AppColors.narText,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          SvgPicture.asset(
            'assets/icons/chevron-down.svg',
            width: 18 * scale,
            height: 18 * scale,
          ),
        ],
      ),
    );
  }

  Widget _buildRound() {
    return Container(
      height: 34 * scale,
      padding: EdgeInsets.only(left: 16 * scale, right: 8 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1,
              color: AppColors.narTextTertiary,
            ),
          ),
          SizedBox(width: 4 * scale),
          SvgPicture.asset(
            'assets/icons/chevron-down.svg',
            width: 24 * scale,
            height: 24 * scale,
          ),
        ],
      ),
    );
  }
}
