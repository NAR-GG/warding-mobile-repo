import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

typedef CalendarMatch = ({String home, String away});

class ScheduleCalendar extends StatelessWidget {
  const ScheduleCalendar({
    super.key,
    required this.month,
    required this.matchesByDay,
  });

  /// 표시할 월 (1일 0시로 정규화된 DateTime).
  final DateTime month;

  /// 일(day) → 그 날의 경기 목록.
  final Map<int, List<CalendarMatch>> matchesByDay;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekdayHeader(scale: scale),
          Expanded(
            child: _MonthGrid(
              month: month,
              scale: scale,
              matchesOf: (date) => date.month == month.month
                  ? (matchesByDay[date.day] ?? const [])
                  : const [],
            ),
          ),
        ],
      ),
    );
  }
}

/// 요일 헤더 — 월·화·수·목·금·토·일.
///
/// 요일 한 칸당 위 14 / 아래 10 패딩을 주고, 행 아래에 1px 그라데이션
/// 구분선([AppColors.narBg])을 둔다.
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.scale});

  final double scale;

  static const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final day in _weekdays)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 14 * scale, bottom: 10 * scale),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600, // SF Pro 590 ≈ Semibold
                      fontSize: 16 * scale,
                      height: 1.0, // line-height 100%
                      letterSpacing: 0,
                      color: AppColors.narTextTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // 주간 구분선 — 1px 그라데이션
        Container(
          height: 1,
          decoration: const BoxDecoration(gradient: AppColors.narBg),
        ),
      ],
    );
  }
}

/// 월간 날짜 그리드.
///
/// 주(week)는 월요일 시작. 이전·다음 달 날짜로 빈 칸을 채워 7×N 격자를
/// 만들고, 각 주 행을 [Expanded] 로 균등 분할해 스크롤 없이 남은 높이를
/// 모두 채운다.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.scale,
    required this.matchesOf,
  });

  final DateTime month;
  final double scale;

  /// 특정 날짜의 경기 목록을 반환한다.
  final List<CalendarMatch> Function(DateTime date) matchesOf;

  @override
  Widget build(BuildContext context) {
    // 그리드 시작일이 속한 주의 월요일까지 거슬러 올라갈 일수.
    final leadingDays = month.weekday - DateTime.monday; // 월요일이면 0
    // 이번 달 일수 (다음 달 0일 = 이번 달 말일).
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 앞쪽 빈 칸 + 이번 달 일수를 7로 올림 → 필요한 주 수.
    final weekCount = ((leadingDays + daysInMonth) / 7).ceil();
    final today = DateTime.now();

    // today 가 그리드에서 몇 번째 주에 있는지 (그리드 밖이면 -1).
    final gridStart = DateTime(month.year, month.month, 1 - leadingDays);
    final todayOffset = DateTime(today.year, today.month, today.day)
        .difference(gridStart)
        .inDays;
    final todayWeek = (todayOffset >= 0 && todayOffset < weekCount * 7)
        ? todayOffset ~/ 7
        : -1;

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var week = 0; week < weekCount; week++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var dow = 0; dow < 7; dow++)
                  Builder(
                    builder: (context) {
                      // DateTime 생성자가 음수·초과 일수를 알아서 정규화한다.
                      final date = DateTime(
                        month.year,
                        month.month,
                        1 - leadingDays + week * 7 + dow,
                      );
                      return Expanded(
                        child: _DayCell(
                          date: date,
                          matches: matchesOf(date),
                          // 마지막 열(일요일) 오른쪽엔 세로 테두리 없음.
                          showRightBorder: dow != 6,
                          // 첫 주만 위쪽 테두리. 이후 행은 윗 행의 아래
                          // 테두리가 위 선 역할을 한다.
                          showTopBorder: week == 0,
                          isToday:
                              date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day,
                          scale: scale,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );

    if (todayWeek < 0) return grid;

    // 배지 오른쪽 끝이 오늘 칸의 왼쪽 세로선에 닿게, 윗 선에 걸치도록 띄운다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 7;
        final rowHeight = constraints.maxHeight / weekCount;
        final todayDow = todayOffset % 7; // 오늘 칸의 열 (월=0 … 일=6)
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            grid,
            Positioned(
              // 오늘 칸 왼쪽 세로선에서 배지 폭(30)만큼 왼쪽으로.
              left: todayDow * cellWidth - 30 * scale,
              top: todayWeek * rowHeight - 24 * scale,
              child: _TodayBadge(scale: scale),
            ),
          ],
        );
      },
    );
  }
}

/// 날짜 한 칸. 왼쪽 상단에 날짜 숫자, 그 아래 경기 칩 세로 스택,
/// 칸 위·아래·오른쪽에 0.5px 구분선(바깥 가장자리·마지막 열 제외).
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.matches,
    required this.showRightBorder,
    required this.showTopBorder,
    required this.isToday,
    required this.scale,
  });

  final DateTime date;
  final List<CalendarMatch> matches;
  final bool showRightBorder;
  final bool showTopBorder;
  final bool isToday;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.narText4, width: 0.5);
    return Container(
      decoration: BoxDecoration(
        gradient: isToday ? AppColors.narTodayBg : null,
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
              top: 3 * scale,
              bottom: 3 * scale,
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
            child: _MatchChipStack(matches: matches, scale: scale),
          ),
        ],
      ),
    );
  }
}

/// 경기 칩들을 세로로 쌓고, 칸 높이를 넘기면 하단에 dots 아이콘을 둔다.
class _MatchChipStack extends StatelessWidget {
  const _MatchChipStack({required this.matches, required this.scale});

  final List<CalendarMatch> matches;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();

    final chipHeight = 23.0 * scale;
    const gap = 1.0; // 칩 사이 간격 1px
    final dotsHeight = 12.0 * scale;

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

        // 넘침 → 하단 dots 자리를 빼고 들어가는 칩 수.
        var fitWithDots = 0;
        while ((fitWithDots + 1) * chipHeight +
                fitWithDots * gap +
                gap +
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
          _MatchChip(match: matches[i], scale: scale),
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

/// 경기 칩 — 50×23, 라운드 8, 1px 테두리. 안에 [홈팀] vs [원정팀].
class _MatchChip extends StatelessWidget {
  const _MatchChip({required this.match, required this.scale});

  final CalendarMatch match;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50 * scale,
      height: 23 * scale,
      padding: EdgeInsets.symmetric(horizontal: 1 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary, // #1F2024
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: AppColors.narLine, width: 1), // #343A40
      ),
      child: Row(
        children: [
          Expanded(child: _teamName(match.home)),
          _vsLabel(),
          Expanded(child: _teamName(match.away)),
        ],
      ),
    );
  }

  Widget _teamName(String name) {
    return Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'SF Pro',
        fontWeight: FontWeight.w400, // Regular
        fontSize: 8 * scale,
        height: 1.0, // 칩 높이(23) 안에서 Row 가 세로 가운데 정렬
        letterSpacing: 0,
        color: AppColors.narText, // #FFFFFF
      ),
    );
  }

  /// 'vs' 라벨 — 빨강(#F03E3E) 텍스트, 배경 없음.
  Widget _vsLabel() {
    return Text(
      'VS',
      style: TextStyle(
        fontFamily: 'SF Pro',
        fontWeight: FontWeight.w400,
        fontSize: 8 * scale,
        height: 1.0,
        letterSpacing: 0,
        color: AppColors.narTextScore, // #F03E3E — vs 텍스트 색
      ),
    );
  }
}

/// 페이지 진입 시 오늘 날짜 칸 좌상단에 잠깐 떴다 사라지는 'today' 배지.
///
/// 2초 동안 보이다가 0.3초에 걸쳐 페이드아웃한 뒤 트리에서 제거된다.
class _TodayBadge extends StatefulWidget {
  const _TodayBadge({required this.scale});

  final double scale;

  @override
  State<_TodayBadge> createState() => _TodayBadgeState();
}

class _TodayBadgeState extends State<_TodayBadge> {
  bool _visible = true;
  bool _removed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
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
