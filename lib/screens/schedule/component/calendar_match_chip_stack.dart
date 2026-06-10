import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'calendar_match.dart';
import 'calendar_match_chip.dart';

/// 경기 칩들을 세로로 쌓고, 칸 높이를 넘기면 하단에 dots 아이콘을 둔다.
class CalendarMatchChipStack extends StatelessWidget {
  const CalendarMatchChipStack({
    super.key,
    required this.matches,
    required this.scale,
  });

  final List<CalendarMatch> matches;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();

    final chipHeight = 18.0 * scale;
    const gap = 1.0; // 칩 사이 간격 1px
    final dotsHeight = 15.0 * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;

        // overflow 표시 없이 들어가는 최대 칩 수.
        var fitAll = 0;
        while ((fitAll + 1) * chipHeight + fitAll * gap <= available) {
          fitAll++;
        }

        if (matches.length <= fitAll) {
          return _stack(matches.length, showDots: false, gap: gap);
        }

        // 넘침 → 하단 dots 자리(높이)만 빼고 들어가는 칩 수.
        // 칩과 dots 사이 간격은 _stack 의 Spacer 가 채우므로 여기선
        // dotsHeight 만 빼면 된다. (gap 까지 빼면 칩이 한 개 덜 들어간다)
        var fitWithDots = 0;
        while ((fitWithDots + 1) * chipHeight +
                fitWithDots * gap +
                dotsHeight <=
            available) {
          fitWithDots++;
        }
        return _stack(fitWithDots, showDots: true, gap: gap, dots: dotsHeight);
      },
    );
  }

  Widget _stack(
    int chipCount, {
    required bool showDots,
    required double gap,
    double dots = 0,
  }) {
    return Column(
      children: [
        for (var i = 0; i < chipCount; i++) ...[
          if (i > 0) SizedBox(height: gap),
          CalendarMatchChip(match: matches[i], scale: scale),
        ],
        if (showDots) ...[
          // dots 는 칸 맨 아래로 — 칩과의 사이는 Spacer 가 채운다.
          const Spacer(),
          SvgPicture.asset('assets/icons/dots.svg', width: dots, height: dots),
        ],
      ],
    );
  }
}
