import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';

/// 마이 구독 날짜 점프 바텀시트 — 월 네비게이터 + 요일 행 + 날짜 그리드.
///
/// 경기일정의 MonthPickerSheet 와 시각 스타일이 같지만, 데이터 소스가 다르다.
/// 경기일정은 서버(fetchCalendar)에서 점을 받지만, 여기선 이미 로컬에 있는
/// 알림 리스트에서 [markedDaysOf] 콜백으로 그 월의 점 일자를 동기 계산한다.
/// (그래서 schedule 위젯을 공유하지 않고 별도로 둔다.)
///
/// 점이 있는 날만 탭할 수 있고, 탭하면 그 날짜를 [Navigator.pop] 으로 반환한다.
class SubscriptionDateSheet extends StatefulWidget {
  const SubscriptionDateSheet({
    super.key,
    required this.initialMonth,
    required this.markedDaysOf,
  });

  /// 처음 보여줄 월.
  final DateTime initialMonth;

  /// 주어진 월에서 점(알림 있음)을 찍을 '일(day)' 집합을 돌려준다.
  final Set<int> Function(DateTime month) markedDaysOf;

  @override
  State<SubscriptionDateSheet> createState() => _SubscriptionDateSheetState();
}

class _SubscriptionDateSheetState extends State<SubscriptionDateSheet> {
  late DateTime _month = DateTime(
    widget.initialMonth.year,
    widget.initialMonth.month,
  );

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _selectDay(int day) {
    Navigator.of(context).pop(DateTime(_month.year, _month.month, day));
  }

  String get _monthLabel =>
      '${_month.year}.${_month.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final markedDays = widget.markedDaysOf(_month);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ArrowButton(
              icon: 'assets/icons/nar-left.svg',
              scale: scale,
              onTap: () => _shiftMonth(-1),
            ),
            SizedBox(width: 15.5 * scale),
            Text(
              _monthLabel,
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w700,
                fontSize: 16 * scale,
                height: 1.5,
                letterSpacing: 0,
                color: AppColors.narTextGnbDefault,
              ),
            ),
            SizedBox(width: 15.5 * scale),
            _ArrowButton(
              icon: 'assets/icons/nar-right.svg',
              scale: scale,
              onTap: () => _shiftMonth(1),
            ),
          ],
        ),
        SizedBox(height: 24 * scale),
        _WeekdayRow(scale: scale),
        _DayGrid(
          month: _month,
          markedDays: markedDays,
          scale: scale,
          onDaySelected: _selectDay,
        ),
      ],
    );
  }
}

/// 좌·우 월 이동 화살표 — 24×24 아이콘.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
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
      child: SvgPicture.asset(icon, width: 24 * scale, height: 24 * scale),
    );
  }
}

/// 요일 행 — 월·화·수·목·금·토·일.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final weekdays = [
      l.weekdayMon,
      l.weekdayTue,
      l.weekdayWed,
      l.weekdayThu,
      l.weekdayFri,
      l.weekdaySat,
      l.weekdaySun,
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31.5 * scale),
      child: SizedBox(
        height: 32 * scale,
        child: Row(
          children: [
            for (final day in weekdays)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.5 * scale),
                  child: Center(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontWeight: FontWeight.w400,
                        fontSize: 16 * scale,
                        height: 1.5,
                        letterSpacing: 0,
                        color: AppColors.narTextGnbDefault,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 날짜 그리드 — 월요일 시작, 한 칸 40×40. 점 없는 날은 탭 불가.
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.month,
    required this.markedDays,
    required this.scale,
    required this.onDaySelected,
  });

  final DateTime month;

  /// 알림이 있는 '일(day)' 집합.
  final Set<int> markedDays;
  final double scale;

  /// 날짜 칸 탭 콜백. 인자는 탭한 '일(day)'.
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final weekCount = ((leadingDays + daysInMonth) / 7).ceil();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31.5 * scale),
      child: Column(
        children: [
          for (var week = 0; week < weekCount; week++)
            Row(
              children: [
                for (var dow = 0; dow < 7; dow++)
                  Expanded(
                    child: _cell(week * 7 + dow - leadingDays + 1, daysInMonth),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return SizedBox(height: 40 * scale);
    }
    final hasMark = markedDays.contains(day);
    return Center(
      child: _DayCell(
        day: day,
        hasMark: hasMark,
        scale: scale,
        // 점 없는 날은 갈 곳이 없으니 탭 비활성.
        onTap: hasMark ? () => onDaySelected(day) : null,
      ),
    );
  }
}

/// 날짜 한 칸 — 40×40. 가운데 날짜 글자, 그 아래 알림 점.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasMark,
    required this.scale,
    required this.onTap,
  });

  final int day;
  final bool hasMark;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40 * scale,
        height: 40 * scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontWeight: FontWeight.w400,
                fontSize: 16 * scale,
                height: 1.5,
                letterSpacing: 0,
                color: hasMark
                    ? AppColors.narTextSecondary
                    : AppColors.narButtonDisabledText,
              ),
            ),
            SizedBox(height: 2 * scale),
            Container(
              width: 4 * scale,
              height: 4 * scale,
              decoration: hasMark
                  ? const BoxDecoration(
                      gradient: AppColors.narBg,
                      shape: BoxShape.circle,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
