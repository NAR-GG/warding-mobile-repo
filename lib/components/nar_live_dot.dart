import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// LIVE 배지 안의 빨간 점. 진행 중임을 알리려 천천히 깜박인다.
///
/// 투명도만 1 ↔ 0.3 으로 오가서(1.2초 주기) 배지 크기·위치는 흔들리지 않는다.
/// 크기가 변하면 옆 'LIVE' 글자가 밀려 리스트 전체가 들썩이기 때문이다.
///
/// 시스템 '동작 줄이기'(iOS Reduce Motion / Android 애니메이션 끄기)가 켜져
/// 있으면 깜박이지 않고 불투명하게 고정한다.
class NarLiveDot extends StatefulWidget {
  const NarLiveDot({super.key, this.scale = 1, this.size = 6});

  final double scale;

  /// 점 지름. 시안 기준 6.
  final double size;

  @override
  State<NarLiveDot> createState() => _NarLiveDotState();
}

class _NarLiveDotState extends State<NarLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 접근성 설정에 따라 애니메이션을 켜고 끈다.
  /// [didChangeDependencies] 에서 보는 이유는 설정이 런타임에 바뀔 수 있어서다.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _ctrl.stop();
      _ctrl.value = 0;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size * widget.scale;
    final dot = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.liveAccent,
        shape: BoxShape.circle,
      ),
    );
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: dot,
    );
  }
}
