import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';
import 'calendar_match.dart';
import 'calendar_match_chip.dart';

/// 경기 칩들을 세로로 쌓고, 칸 높이를 넘기면 하단에 dots 아이콘을 둔다.
///
/// [isLoading] 이면 이 칸에 실제로 경기가 있는지 아직 모르는 상태다(그 달
/// 조회가 진행 중). 빈 칸으로 두면 응답이 온 순간 칩이 갑자기 팝업하듯
/// 나타나 눈에 띄므로, 그 대신 자리 하나만큼 펄스하는 스켈레톤 바를
/// 보여준다 — 실제 칩이 없을 수도 있는 자리라 하나만 그린다.
class CalendarMatchChipStack extends StatefulWidget {
  const CalendarMatchChipStack({
    super.key,
    required this.matches,
    required this.scale,
    this.isLoading = false,
  });

  final List<CalendarMatch> matches;
  final double scale;
  final bool isLoading;

  @override
  State<CalendarMatchChipStack> createState() =>
      _CalendarMatchChipStackState();
}

class _CalendarMatchChipStackState extends State<CalendarMatchChipStack>
    with SingleTickerProviderStateMixin {
  // 티커는 State 하나당 하나만 허용된다(SingleTickerProviderStateMixin).
  // isLoading 이 토글될 때마다 컨트롤러를 새로 만들고 지우면, dispose 가 그
  // 프레임 안에서 완전히 끝나기 전에 새 컨트롤러가 만들어져 "multiple
  // tickers" 예외가 났다. 그 대신 컨트롤러는 initState 에서 딱 한 번만
  // 만들고(isLoading 이 false 라도), isLoading 에 따라 repeat/stop 만
  // 토글한다.
  //
  // late final 초기화식으로 두면 안 된다 — build 에서 한 번도 안 쓰이는
  // 칸(경기 없는 날)은 dispose() 의 `_pulseCtrl.dispose()` 호출에서야
  // 처음 초기화되는데, 그 시점은 이미 위젯이 dispose 중이라
  // createTicker 가 예외를 던진다.
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.isLoading) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(CalendarMatchChipStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading == oldWidget.isLoading) return;
    if (widget.isLoading) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _loadingPlaceholder();

    final matches = widget.matches;
    final scale = widget.scale;
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
    final matches = widget.matches;
    final scale = widget.scale;
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

  /// 칩 한 자리 크기의 펄스 바. 실제 칩이 그 자리에 있을지는 아직 몰라서
  /// 자리를 하나만 예약해 둔다 — 응답이 오면 그 위치에서 실제 칩(들)으로
  /// 바로 이어져, 빈 칸에서 칩이 팝업하듯 나타나는 느낌을 줄인다.
  Widget _loadingPlaceholder() {
    final scale = widget.scale;
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final opacity = 0.3 + (_pulseCtrl.value * 0.3); // 0.3 ↔ 0.6 펄스
        return Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: 28 * scale,
            height: 8 * scale,
            decoration: BoxDecoration(
              color: AppColors.narLine2.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}
