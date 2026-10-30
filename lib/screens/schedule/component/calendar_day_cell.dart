import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import 'calendar_match.dart';
import 'calendar_match_chip_stack.dart';

/// 날짜 한 칸. 왼쪽 상단에 날짜 숫자, 그 아래 경기 칩 세로 스택,
/// 칸 위·아래·오른쪽에 0.5px 구분선(바깥 가장자리·마지막 열 제외).
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.matches,
    required this.showRightBorder,
    required this.showTopBorder,
    required this.isToday,
    required this.isSelected,
    required this.scale,
    this.onTap,
  });

  final DateTime date;
  final List<CalendarMatch> matches;
  final bool showRightBorder;
  final bool showTopBorder;
  final bool isToday;

  /// 날짜 피커에서 고른 날짜인지. true 면 칸 배경을 강조한다.
  final bool isSelected;
  final double scale;

  /// 칸을 탭했을 때 콜백. null 이면 탭 비활성(경기 없는 날·다른 달 칸 등).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.narText4, width: 0.5);
    final cell = Container(
      decoration: BoxDecoration(
        // 선택 칸은 narDark500 단색, 아니면 오늘 칸만 그라데이션.
        color: isSelected ? AppColors.narDark500 : null,
        gradient: !isSelected && isToday ? AppColors.narTodayBg : null,
        border: Border(
          top: showTopBorder ? side : BorderSide.none,
          bottom: side,
          right: showRightBorder ? side : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 날짜 숫자 — 좌상단
          Padding(
            padding: EdgeInsets.only(
              left: 4 * scale,
              // 위아래 3 → 2. 칸 높이를 늘리는 대신 여기서 아낀 4px 를
              // 칩 자리로 돌린다(칸 하나에 칩을 더 많이 보이게 하려는 것).
              top: 2 * scale,
              bottom: 2 * scale,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600, // SF Pro 590 ≈ Semibold
                  fontSize: 14 * scale,
                  height: 1.0, // line-height 100%
                  letterSpacing: 0,
                  color: isToday ? AppColors.narTextRed : AppColors.narText4,
                ),
              ),
            ),
          ),
          // 경기 칩 세로 스택 — 남은 높이 안에서, 넘치면 dots.
          Expanded(
            child: CalendarMatchChipStack(matches: matches, scale: scale),
          ),
        ],
      ),
    );

    final tap = onTap;
    if (tap == null) return cell;
    // 탭만 받고 드래그는 흘려보낸다.
    //
    // [GestureDetector] 를 쓰면 칸마다 탭 인식기가 제스처 아레나에 들어가,
    // 캘린더를 좌우로 쓸 때 **PageView 가 드래그를 못 받는다**(월·주 이동이
    // 통째로 죽는다). 칸은 한 줄 높이(64)뿐이라 세로로 멀어질 여지도 없어
    // 아레나가 탭 쪽으로 기울기 쉽다.
    //
    // 대신 '탭 다운 → 같은 칸에서 탭 업' 만 직접 본다. 손가락이 움직이기
    // 시작하면([onPointerMove] 문턱 초과) 탭을 포기해 스크롤에 양보한다.
    return _TapOnly(onTap: tap, child: cell);
  }
}

/// 탭만 받고 드래그는 부모(스크롤·페이저)에 양보하는 얇은 래퍼.
///
/// [GestureDetector] 대신 [Listener] 를 쓴다 — 제스처 아레나에 참가하지
/// 않으므로 같은 자리의 [PageView] 가 드래그를 그대로 가져간다. 캘린더
/// 날짜 칸처럼 "탭은 되어야 하는데 좌우 스와이프를 막으면 안 되는" 자리에 쓴다.
class _TapOnly extends StatefulWidget {
  const _TapOnly({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TapOnly> createState() => _TapOnlyState();
}

class _TapOnlyState extends State<_TapOnly> {
  /// 탭으로 인정할 최대 이동 거리(px). 이보다 움직이면 스크롤로 본다.
  static const double _slop = 12;

  Offset? _downAt;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _downAt = e.position,
      onPointerMove: (e) {
        final down = _downAt;
        if (down == null) return;
        if ((e.position - down).distance > _slop) _downAt = null;
      },
      onPointerUp: (e) {
        final down = _downAt;
        _downAt = null;
        if (down == null) return;
        if ((e.position - down).distance <= _slop) widget.onTap();
      },
      onPointerCancel: (_) => _downAt = null,
      child: widget.child,
    );
  }
}
