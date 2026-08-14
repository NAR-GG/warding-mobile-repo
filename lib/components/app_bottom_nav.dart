import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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

  /// 탭 순서·아이콘 정의 (디자인 시안 순서). 라벨은 build에서 l10n으로 가져온다.
  static const List<({String icon, AppNavTab tab})> _items = [
    (icon: 'assets/icons/calendar-event.svg', tab: AppNavTab.schedule),
    (icon: 'assets/icons/layout-list.svg', tab: AppNavTab.list),
    (icon: 'assets/icons/empty-stars.svg', tab: AppNavTab.subscription),
    (icon: 'assets/icons/user.svg', tab: AppNavTab.mypage),
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
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    final labels = {
      AppNavTab.schedule: l.navSchedule,
      AppNavTab.list: l.navMatchList,
      AppNavTab.subscription: l.navSubscription,
      AppNavTab.mypage: l.navMyPage,
    };

    final children = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final active = item.tab == currentTab;

      children.add(
        active
            // 활성 탭만 라벨을 갖고 minWidth 113 을 요구한다. 좁은 화면(320)에서
            // 고정폭 chip 3개 + gap 과 합쳐 바 폭(335)을 2.6px 넘겨 RenderFlex
            // overflow 가 났다. Flexible 로 감싸 남는 폭에 맞춰 줄어들게 한다
            // (라벨은 아래 Text 의 ellipsis 가 처리).
            ? Flexible(
                child: _NavItemActive(
                  icon: item.icon,
                  label: labels[item.tab]!,
                  scale: scale,
                  onTap: () => onTabSelected(item.tab),
                ),
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

    final bar = SizedBox(
      width: 335 * scale,
      height: 72 * scale,
      child: Padding(
        padding: EdgeInsets.all(12 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );

    // 유리 효과는 셰이더용 지오메트리 이미지를 `toImageSync(w.ceil(),
    // h.ceil())` 로 만드는데, 그 크기는 렌더 트랜스폼과 devicePixelRatio 에서
    // 나온다. 화면에 실제 면적이 없는 프레임(탭 전환·라우트 전환 중간,
    // 축소 애니메이션, 오프스크린 프리워밍)에서는 0 으로 떨어져
    // 'Invalid image dimensions.' 로 죽는다
    // (Sentry WARDING-APP-FLUTTER-A, 3.6K events / 925 users — 전체 1위).
    //
    // 효과는 장식일 뿐이라 앱을 죽일 이유가 없다. 그릴 면적이 있는 프레임에서만
    // 유리를 얹고, 그 밖에는 같은 치수의 불투명 배경으로 대체한다.
    return Center(
      child: _GlassOrFallback(
        scale: scale,
        settings: _glassSettings,
        child: bar,
      ),
    );
  }
}

/// 그릴 면적이 있는 프레임에서만 유리 효과를 얹는다.
///
/// 첫 빌드에서는 아직 렌더박스 크기를 알 수 없어 대체 배경으로 그리고,
/// 레이아웃이 잡힌 다음 프레임에 유리로 승격한다. 사용자에게는 한 프레임
/// 차이라 보이지 않지만, 면적 0 인 프레임에 셰이더가 도는 것을 막아준다.
class _GlassOrFallback extends StatefulWidget {
  const _GlassOrFallback({
    required this.scale,
    required this.settings,
    required this.child,
  });

  final double scale;
  final LiquidGlassSettings settings;
  final Widget child;

  @override
  State<_GlassOrFallback> createState() => _GlassOrFallbackState();
}

class _GlassOrFallbackState extends State<_GlassOrFallback> {
  final GlobalKey _boxKey = GlobalKey();
  bool _canRenderGlass = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void didUpdateWidget(_GlassOrFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  /// 렌더박스가 셰이더를 돌릴 만한 실제 면적을 갖는지 확인한다.
  void _evaluate() {
    if (!mounted) return;
    final box = _boxKey.currentContext?.findRenderObject();
    final ok = box is RenderBox &&
        box.hasSize &&
        box.size.width >= 1 &&
        box.size.height >= 1 &&
        box.size.width.isFinite &&
        box.size.height.isFinite;
    if (ok != _canRenderGlass) setState(() => _canRenderGlass = ok);
  }

  @override
  Widget build(BuildContext context) {
    final sized = KeyedSubtree(key: _boxKey, child: widget.child);
    if (!_canRenderGlass) {
      return _FallbackNavBackground(scale: widget.scale, child: sized);
    }
    return LiquidGlassLayer(
      settings: widget.settings,
      child: LiquidGlass(
        shape: LiquidRoundedRectangle(borderRadius: 38 * widget.scale),
        child: sized,
      ),
    );
  }
}

/// 유리 효과를 그릴 수 없는 프레임에서 쓰는 대체 배경.
///
/// 시각적으로 유리와 완전히 같지는 않지만 같은 치수·라운드를 유지해
/// 레이아웃이 튀지 않는다. 효과 없이도 탭은 정상 동작한다.
class _FallbackNavBackground extends StatelessWidget {
  const _FallbackNavBackground({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.narNavBg,
        borderRadius: BorderRadius.circular(38 * scale),
      ),
      child: child,
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
            // 좁은 화면에서 라벨이 줄어들 수 있어야 한다 — 안 그러면 Row 가
            // 고정폭을 요구해 바 폭을 넘긴다.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * scale,
                  height: 24 / 14,
                  letterSpacing: 0,
                  color: AppColors.narGray400,
                ),
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
