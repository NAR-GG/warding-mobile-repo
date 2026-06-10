import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 페이지 진입 시 오늘 날짜 칸 좌상단에 잠깐 떴다 사라지는 'today' 배지.
///
/// 2초 동안 보이다가 0.3초에 걸쳐 페이드아웃한 뒤 트리에서 제거된다.
class CalendarTodayBadge extends StatefulWidget {
  const CalendarTodayBadge({super.key, required this.scale});

  final double scale;

  @override
  State<CalendarTodayBadge> createState() => _CalendarTodayBadgeState();
}

class _CalendarTodayBadgeState extends State<CalendarTodayBadge> {
  bool _visible = true;
  bool _removed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      onEnd: () {
        if (!_visible && mounted) setState(() => _removed = true);
      },
      child: SvgPicture.asset(
        'assets/icons/today.svg',
        width: 30 * widget.scale,
      ),
    );
  }
}
