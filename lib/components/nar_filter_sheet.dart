import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../styles/app_colors.dart';
import 'common_button.dart';

/// 공용 필터/선택 바텀시트 스캐폴드.
///
/// 헤더([초기화] · [title] · [닫기]) + 본문([child]) + 하단 조회 버튼으로 구성된다.
/// 경기 필터·선수 선택처럼 "리셋·타이틀·닫기 헤더 + 조회 버튼" 형태의 시트를
/// 공통으로 그린다. [showAppBottomSheet] 의 child 로 띄운다.
///
/// 본문은 사용처가 [child] 로 주입한다 (좌우 들여쓰기 등은 본문이 직접 준다).
class NarFilterSheet extends StatelessWidget {
  const NarFilterSheet({
    super.key,
    required this.title,
    required this.child,
    this.onReset,
    this.onClose,
    this.onApply,
    this.applyLabel = '조회하기',
  });

  /// 헤더 가운데 타이틀.
  final String title;

  /// 시트 본문.
  final Widget child;

  /// 좌측 초기화(리셋) 버튼 콜백. null 이면 탭이 무시된다.
  final VoidCallback? onReset;

  /// 우측 닫기 버튼 콜백. null 이면 [Navigator.pop] 한다.
  final VoidCallback? onClose;

  /// 하단 조회 버튼 콜백. null 이면 버튼이 비활성된다.
  final VoidCallback? onApply;

  /// 하단 버튼 라벨.
  final String applyLabel;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(
          title: title,
          scale: scale,
          onReset: onReset,
          onClose: onClose ?? () => Navigator.of(context).pop(),
        ),
        child,
        SizedBox(height: 24 * scale), // 본문 ↔ 조회 버튼 간격 24
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          child: CommonButton(
            label: applyLabel,
            scale: scale,
            onPressed: onApply,
          ),
        ),
      ],
    );
  }
}

/// 시트 헤더 — 위아래 24 간격, [초기화] · [title] · [닫기].
///
/// 초기화·닫기 아이콘이 양옆 44×44 로 같은 크기라, space-between 만으로도
/// 가운데 타이틀이 정확히 중앙에 온다.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.scale,
    required this.onClose,
    this.onReset,
  });

  final String title;
  final double scale;
  final VoidCallback onClose;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24 * scale), // 위아래 24
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconButton(
            icon: 'assets/icons/reset.svg',
            // reset.svg 는 viewBox 44 (버튼 영역째 그려짐) — 44 로 렌더.
            iconSize: 44,
            scale: scale,
            onTap: onReset,
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w700,
              fontSize: 16 * scale,
              height: 1.5, // line-height 150%
              letterSpacing: 0,
              color: AppColors.narTextGnbDefault, // #CED4DA
            ),
          ),
          _IconButton(
            icon: 'assets/icons/close.svg',
            scale: scale,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

/// 헤더의 아이콘 버튼 — 터치영역 44×44, 아이콘은 [iconSize].
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.scale,
    this.iconSize = 24,
    this.onTap,
  });

  final String icon;
  final double scale;

  /// 아이콘 렌더 크기 (터치영역은 항상 44).
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44 * scale,
        height: 44 * scale,
        child: Center(
          child: SvgPicture.asset(
            icon,
            width: iconSize * scale,
            height: iconSize * scale,
          ),
        ),
      ),
    );
  }
}
