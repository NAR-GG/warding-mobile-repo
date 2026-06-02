import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';

/// [NarChip.active] 의 우측 트레일링 아이콘 종류.
enum NarChipTrailing {
  /// chevron-down — 탭하면 옵션을 펼치는 용도.
  chevron,

  /// circle-x — 탭하면 해당 선택을 해제하는 용도.
  remove,
}

/// 공용 선택 칩 (Pill 모양, 높이 34).
///
/// - 기본([NarChip.new]): 토글 선택 칩.
///   선택 시 보라 반투명 배경 + 흰 글자, 미선택 시 어두운 배경 + 회색 글자 + 테두리.
/// - 드롭다운([NarChip.dropdown]): 우측에 chevron-down 아이콘이 붙은 트리거 칩.
///   항상 어두운 배경 + 테두리이고, 탭하면 옵션을 펼치는 용도.
/// - 필터([NarChip.filter]): 우측에 circle-x 아이콘이 붙은 활성 필터칩.
///   보라 테두리 + 보라 텍스트이고, 탭하면 해당 필터를 해제하는 용도.
/// - 활성([NarChip.active]): 보라 테두리 + 보라 텍스트 칩.
///   라벨 옆에 선택 수/요약 [badge] 를, 우측에 [trailing] 아이콘을 둔다.
///   '선수 2명 + chevron', '전체 + circle-x' 처럼 선택 요약 칩에 두루 쓴다.
class NarChip extends StatelessWidget {
  const NarChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.scale = 1,
  }) : _variant = _ChipVariant.toggle,
       badge = null,
       trailing = NarChipTrailing.chevron,
       onRemove = null;

  /// chevron-down 트레일링 아이콘이 붙은 드롭다운 트리거 칩.
  const NarChip.dropdown({
    super.key,
    required this.label,
    this.onTap,
    this.scale = 1,
  }) : selected = false,
       _variant = _ChipVariant.dropdown,
       badge = null,
       trailing = NarChipTrailing.chevron,
       onRemove = null;

  /// circle-x 트레일링 아이콘이 붙은 활성 필터칩. 탭하면 필터 해제.
  const NarChip.filter({
    super.key,
    required this.label,
    this.onTap,
    this.scale = 1,
  }) : selected = true,
       _variant = _ChipVariant.filter,
       badge = null,
       trailing = NarChipTrailing.chevron,
       onRemove = null;

  /// 보라 테두리 활성 칩. 라벨 + (옵션)[badge] + [trailing] 아이콘.
  ///
  /// [trailing] 이 [NarChipTrailing.remove] 면 circle-x 영역 탭만 [onRemove] 로,
  /// 나머지 본문 탭은 [onTap] 으로 간다.
  const NarChip.active({
    super.key,
    required this.label,
    this.badge,
    this.trailing = NarChipTrailing.chevron,
    this.onTap,
    this.onRemove,
    this.scale = 1,
  }) : selected = false,
       _variant = _ChipVariant.active;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double scale;

  /// 활성 칩의 라벨 옆 배지 텍스트 (선택 수·'전체' 등). null 이면 배지 없음.
  final String? badge;

  /// 활성 칩의 우측 트레일링 아이콘.
  final NarChipTrailing trailing;

  /// 활성 칩에서 [NarChipTrailing.remove] 의 circle-x 탭 콜백.
  final VoidCallback? onRemove;

  /// 칩 형태.
  final _ChipVariant _variant;

  @override
  Widget build(BuildContext context) {
    switch (_variant) {
      case _ChipVariant.dropdown:
        return _buildDropdown();
      case _ChipVariant.filter:
        return _buildFilter();
      case _ChipVariant.active:
        return _buildActive();
      case _ChipVariant.toggle:
        return _buildToggle();
    }
  }

  Widget _buildToggle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34 * scale,
        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.narChipSelectedBg
              : AppColors.narBgTertiary,
          border: selected
              ? null
              : Border.all(color: AppColors.narLine2, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        // Row(min) 으로 내용 크기만 차지 — Wrap 등 너비 제약 부모에서 늘어남 방지.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 1,
                color: selected ? AppColors.narText : AppColors.narText2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 드롭다운 트리거 칩: 좌 16 / 우 8 패딩, 라벨과 chevron 사이 gap 4.
  Widget _buildDropdown() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34 * scale,
        padding: EdgeInsets.only(left: 16 * scale, right: 8 * scale),
        decoration: BoxDecoration(
          color: AppColors.narBgTertiary,
          border: Border.all(color: AppColors.narLine2, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1,
                color: AppColors.narTextTertiary,
              ),
            ),
            SizedBox(width: 4 * scale), // gap 4
            SvgPicture.asset(
              'assets/icons/chevron-down.svg',
              width: 24 * scale,
              height: 24 * scale,
              colorFilter: const ColorFilter.mode(
                AppColors.narTextTertiary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 활성 필터칩: 좌 16 / 우 8 패딩, 라벨과 circle-x 사이 gap 3.
  /// 보라 테두리 + 보라 텍스트, 어두운 배경.
  Widget _buildFilter() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34 * scale,
        padding: EdgeInsets.only(left: 16 * scale, right: 8 * scale),
        decoration: BoxDecoration(
          color: AppColors.narDark800,
          border: Border.all(color: AppColors.narChipActive, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 1,
                color: AppColors.narChipActive,
              ),
            ),
            SizedBox(width: 3 * scale), // gap 3
            SvgPicture.asset(
              'assets/icons/circle-x.svg',
              width: 24 * scale,
              height: 24 * scale,
              colorFilter: const ColorFilter.mode(
                AppColors.narChipActive,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 활성 칩: 좌 16 / 우 8 패딩, 라벨 + (옵션)배지 + trailing 아이콘 (gap 4).
  /// 보라 테두리 + 보라 텍스트, 어두운 배경.
  Widget _buildActive() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 34 * scale,
        padding: EdgeInsets.only(left: 16 * scale, right: 8 * scale),
        decoration: BoxDecoration(
          color: AppColors.narDark800,
          border: Border.all(color: AppColors.narChipActive, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 16 * scale,
                height: 1,
                color: AppColors.narChipActive,
              ),
            ),
            if (badge != null) ...[
              SizedBox(width: 4 * scale), // gap 4
              _ChipBadge(text: badge!, scale: scale),
            ],
            SizedBox(width: 4 * scale), // gap 4
            if (trailing == NarChipTrailing.chevron)
              SvgPicture.asset(
                'assets/icons/chevron-down.svg',
                width: 24 * scale,
                height: 24 * scale,
                colorFilter: const ColorFilter.mode(
                  AppColors.narChipActive,
                  BlendMode.srcIn,
                ),
              )
            else
              // circle-x 영역만 onRemove (중첩 GestureDetector — 자식이 우선).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: _RemoveIcon(scale: scale),
              ),
          ],
        ),
      ),
    );
  }
}

/// 활성 칩의 배지 — 보라 30% stadium, 가운데 텍스트 (선택 수·'전체' 등).
class _ChipBadge extends StatelessWidget {
  const _ChipBadge({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20 * scale,
      constraints: BoxConstraints(minWidth: 20 * scale),
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.narChipBadgeBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
          fontSize: 12 * scale,
          height: 1,
          color: AppColors.narChipActive,
        ),
      ),
    );
  }
}

/// 활성 칩의 circle-x — 보라 30% 원 + 흰 X.
class _RemoveIcon extends StatelessWidget {
  const _RemoveIcon({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20 * scale,
      height: 20 * scale,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.narChipBadgeBg,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        'assets/icons/close.svg',
        width: 12 * scale,
        height: 12 * scale,
      ),
    );
  }
}

/// 칩 형태 구분.
enum _ChipVariant { toggle, dropdown, filter, active }
