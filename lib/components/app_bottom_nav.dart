import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../styles/app_colors.dart';

enum AppNavTab { schedule, list, subscription, mypage }


class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    this.currentTab = AppNavTab.schedule,
    required this.onTabSelected,
  });

  /// 현재 활성 탭. 기본값은 경기일정([AppNavTab.schedule]).
  final AppNavTab currentTab;

  /// 탭 선택 콜백.
  final ValueChanged<AppNavTab> onTabSelected;

  /// 탭 순서·아이콘·라벨 정의 (디자인 시안 순서).
  static const List<({String icon, String label, AppNavTab tab})> _items = [
    (
      icon: 'assets/icons/calendar-event.svg',
      label: '경기일정',
      tab: AppNavTab.schedule,
    ),
    (icon: 'assets/icons/layout-list.svg', label: '경기리스트', tab: AppNavTab.list),
    (
      icon: 'assets/icons/stars.svg',
      label: '마이 구독',
      tab: AppNavTab.subscription,
    ),
    (icon: 'assets/icons/user.svg', label: '마이페이지', tab: AppNavTab.mypage),
  ];

  static const LiquidGlassSettings _glassSettings = LiquidGlassSettings(
    thickness: 16,
    blur: 12,
    refractiveIndex: 1.33,
    glassColor: AppColors.narNavBg,
    lightIntensity: 0.2,
    saturation: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    final children = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final active = item.tab == currentTab;

      children.add(
        active
            ? _NavItemActive(
                icon: item.icon,
                label: item.label,
                scale: scale,
                onTap: () => onTabSelected(item.tab),
              )
            : _NavItemInactive(
                icon: item.icon,
                scale: scale,
                onTap: () => onTabSelected(item.tab),
              ),
      );

      if (i != _items.length - 1) {
        children.add(SizedBox(width: 16 * scale)); // gap 16
      }
    }

    return Center(
      child: LiquidGlassLayer(
        settings: _glassSettings,
        child: LiquidGlass(
          shape: LiquidRoundedRectangle(borderRadius: 38 * scale),
          child: SizedBox(
            width: 335 * scale,
            height: 72 * scale,
            child: Padding(
              padding: EdgeInsets.all(12 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemActive extends StatelessWidget {
  const _NavItemActive({
    required this.icon,
    required this.label,
    required this.scale,
    required this.onTap,
  });

  final String icon;
  final String label;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48 * scale,
        constraints: BoxConstraints(minWidth: 113 * scale),
        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        decoration: BoxDecoration(
          color: AppColors.narNavSelectedBg,
          borderRadius: BorderRadius.circular(26 * scale),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              width: 24 * scale,
              height: 24 * scale,
              colorFilter: const ColorFilter.mode(
                AppColors.narGray400,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 8 * scale), // gap 8
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 14 * scale,
                height: 24 / 14,
                letterSpacing: 0,
                color: AppColors.narGray400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 비활성 탭: 44x44 고정 chip, 아이콘만 표시.
class _NavItemInactive extends StatelessWidget {
  const _NavItemInactive({
    required this.icon,
    required this.scale,
    required this.onTap,
  });

  final String icon;
  final double scale;
  final VoidCallback onTap;

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
            width: 24 * scale,
            height: 24 * scale,
            colorFilter: const ColorFilter.mode(
              AppColors.narDark200,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
