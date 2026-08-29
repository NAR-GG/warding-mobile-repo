import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../styles/app_colors.dart';

enum AppNavTab { schedule, list, community, subscription, mypage }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    this.currentTab = AppNavTab.schedule,
    required this.onTabSelected,
    this.compact = false,
  });

  /// 현재 활성 탭. 기본값은 경기일정([AppNavTab.schedule]).
  final AppNavTab currentTab;

  /// 탭 선택 콜백.
  final ValueChanged<AppNavTab> onTabSelected;

  /// 축소 표시 여부. 목록을 내리는 동안 살짝 작아져 콘텐츠를 덜 가린다.
  /// 스크롤 방향에 맞춰 켜고 끄려면 [BottomNavShrinkController] 를 쓴다.
  final bool compact;

  /// 축소 시 배율. 라벨까지 같이 줄어들어 읽기 힘들어지지 않도록 완만하게 잡았다.
  static const double _compactFactor = 0.82;

  /// 탭 순서·아이콘 정의 (디자인 시안 순서). 라벨은 build에서 l10n으로 가져온다.
  static const List<({String icon, AppNavTab tab})> _items = [
    (icon: 'assets/icons/calendar-event.svg', tab: AppNavTab.schedule),
    (icon: 'assets/icons/layout-list.svg', tab: AppNavTab.list),
    (
      icon: 'assets/icons/message-circle-heart.svg',
      tab: AppNavTab.community,
    ),
    (icon: 'assets/icons/empty-stars.svg', tab: AppNavTab.subscription),
    (icon: 'assets/icons/user.svg', tab: AppNavTab.mypage),
  ];

  /// 탭이 5개가 되며 바 폭(335)에 맞추기 위해 좁힌 비활성 chip 치수.
  ///
  /// 활성 chip 폭은 라벨 길이에 따라 달라진다(고정폭 아님). 간격을
  /// 고정 gap 대신 [MainAxisAlignment.spaceBetween] 으로 자동 분배해,
  /// 활성 라벨이 길어져도 잘리지 않고 남는 폭만 간격이 줄어든다.
  static const double _inactiveSize = 40;

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
      AppNavTab.community: l.navCommunity,
      AppNavTab.subscription: l.navSubscription,
      AppNavTab.mypage: l.navMyPage,
    };

    final children = [
      for (final item in _items)
        if (item.tab == currentTab)
          Flexible(
            child: _NavItemActive(
              icon: item.icon,
              label: labels[item.tab]!,
              scale: scale,
              onTap: () => onTabSelected(item.tab),
            ),
          )
        else
          _NavItemInactive(
            icon: item.icon,
            scale: scale,
            onTap: () => onTabSelected(item.tab),
          ),
    ];

    // 탭 전환은 [tabRoute] 로 화면 자체가 통째로 교체돼(각 화면이 자기
    // AppBottomNav 를 따로 그림) 이 위젯의 State 는 탭이 바뀔 때마다 새로
    // 생성된다 — 로컬 애니메이션으로는 이전 위치에서 이어 그릴 방법이 없다.
    // 대신 활성 pill 배경만 [Hero] 로 감싸 화면 전환(Navigator) 동안
    // Flutter 가 직접 이전 화면의 pill 위치 → 새 화면의 pill 위치로
    // 날아가는 모션을 만들게 한다.
    final bar = SizedBox(
      width: 335 * scale,
      height: 72 * scale,
      child: Padding(
        padding: EdgeInsets.all(12 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        ),
      ),
    );

    // 축소는 AnimatedScale 로 통째로 줄인다. LiquidGlass 는 셰이더로 유리를
    // 그려서 내부 치수를 따로 애니메이션하면 굴절 모양이 프레임마다 다시 잡혀
    // 일렁인다. 통째 스케일이면 그려진 결과만 축소돼 매끄럽다.
    //
    // alignment 를 bottomCenter 로 둬서 줄어들 때 아래쪽 여백(각 화면의
    // Positioned bottom)이 유지된 채 위쪽으로만 작아진다.
    //
    // 유리 효과는 셰이더용 지오메트리 이미지를 `toImageSync(w.ceil(),
    // h.ceil())` 로 만드는데, 그 크기는 렌더 트랜스폼과 devicePixelRatio 에서
    // 나온다. 화면에 실제 면적이 없는 프레임(탭 전환·라우트 전환 중간,
    // 축소 애니메이션 도중, 오프스크린 프리워밍)에서는 0 으로 떨어져
    // 'Invalid image dimensions.' 로 죽는다
    // (Sentry WARDING-APP-FLUTTER-A, 3.6K events / 925 users — 전체 1위).
    // 위 축소 애니메이션이 정확히 그 조건을 매 프레임 만들므로,
    // [_GlassOrFallback] 이 면적을 확인한 프레임에서만 유리를 얹는다.
    return Center(
      child: AnimatedScale(
        scale: compact ? _compactFactor : 1,
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: _GlassOrFallback(
          scale: scale,
          settings: _glassSettings,
          child: bar,
        ),
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

/// 스크롤 방향을 보고 [AppBottomNav] 의 축소 여부를 들고 있는 컨트롤러.
///
/// 화면마다 스크롤 주체가 달라(ListView·SingleChildScrollView·컨트롤러 없음)
/// [ScrollController] 를 넘겨받는 대신 [ScrollNotification] 을 듣는다.
/// 스크롤 영역을 [NotificationListener] 로 감싸 [handleNotification] 에 연결하고,
/// [AppBottomNav] 는 이 컨트롤러를 구독해 [AppBottomNav.compact] 를 받는다.
///
/// 화면 State 에서 만들고 [dispose] 해 쓴다:
/// ```dart
/// final _navShrink = BottomNavShrinkController();
/// // build:
/// NotificationListener<ScrollNotification>(
///   onNotification: _navShrink.handleNotification,
///   child: ...,
/// )
/// ListenableBuilder(
///   listenable: _navShrink,
///   builder: (_, _) => AppBottomNav(..., compact: _navShrink.compact),
/// )
/// ```
class BottomNavShrinkController extends ChangeNotifier {
  /// 축소/복귀를 뒤집는 데 필요한 최소 스크롤 이동량(px).
  /// 손떨림 수준의 움직임으로 크기가 깜빡이지 않게 한다.
  static const double _toggleDelta = 12;

  bool _compact = false;
  double _accumulated = 0;

  /// 지금 축소 상태인지.
  bool get compact => _compact;

  void _set(bool value) {
    if (_compact == value) return;
    _compact = value;
    notifyListeners();
  }

  /// [NotificationListener.onNotification] 에 그대로 넘긴다.
  /// 알림을 소비하지 않으므로(항상 false) 다른 리스너에도 그대로 전파된다.
  bool handleNotification(ScrollNotification n) {
    // 가로 스크롤(경기일정 주간 페이저 등)은 무시한다.
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is! ScrollUpdateNotification) return false;

    final delta = n.scrollDelta;
    if (delta == null) return false;

    // reverse:true 인 목록(경기리스트 오름차순 정렬)은 offset 증가가 화면상
    // '위로 올라감'이라 방향이 뒤집힌다. 실제로 어느 쪽으로 밀었는지는
    // axisDirection 으로 판단한다(reverse 면 up).
    final reversed = n.metrics.axisDirection == AxisDirection.up;
    final scrolledDown = reversed ? delta < 0 : delta > 0;

    // 맨 위(=목록 시작)에서는 항상 원래 크기로 둔다. 오버스크롤 튕김으로
    // 작아지는 걸 막는다. reverse 목록에서는 offset 최대치가 목록 시작이다.
    final atTop =
        reversed
            ? n.metrics.pixels >= n.metrics.maxScrollExtent - 1
            : n.metrics.pixels <= n.metrics.minScrollExtent + 1;
    if (atTop) {
      _accumulated = 0;
      _set(false);
      return false;
    }

    // 같은 방향으로 연속해 움직인 양만 누적하고, 방향이 바뀌면 리셋한다.
    if (scrolledDown == (_accumulated > 0)) {
      _accumulated += scrolledDown ? delta.abs() : -delta.abs();
    } else {
      _accumulated = scrolledDown ? delta.abs() : -delta.abs();
    }

    if (_accumulated.abs() < _toggleDelta) return false;
    _set(_accumulated > 0);
    return false;
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

/// 비활성 탭: [AppBottomNav._inactiveSize] 정사각 고정 chip, 아이콘만 표시.
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
        width: AppBottomNav._inactiveSize * scale,
        height: AppBottomNav._inactiveSize * scale,
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
