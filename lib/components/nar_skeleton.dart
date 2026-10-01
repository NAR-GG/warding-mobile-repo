import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 스켈레톤 한 묶음을 같은 박자로 깜박이게 하는 래퍼(1.1초 주기, 0.5↔1.0).
///
/// 자식 안의 [NarSkeletonBox] 들이 한꺼번에 숨 쉬듯 보이도록 박스마다 애니메이션을
/// 두지 않고 묶음 전체에 하나만 건다. 동작 줄이기 설정이면 깜박임 없이 고정한다.
class NarSkeleton extends StatefulWidget {
  const NarSkeleton({super.key, required this.child});

  final Widget child;

  @override
  State<NarSkeleton> createState() => _NarSkeletonState();
}

class _NarSkeletonState extends State<NarSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.5,
    end: 1,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  bool? _reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce == _reduce) return;
    _reduce = reduce;
    if (reduce) {
      _ctrl.stop();
      _ctrl.value = 1;
    } else {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

/// 스켈레톤의 회색 박스. [NarSkeleton] 안에서 쓴다.
class NarSkeletonBox extends StatelessWidget {
  const NarSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.narLine2.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
