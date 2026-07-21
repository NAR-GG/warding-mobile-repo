import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../styles/app_colors.dart';
import '../../../viewmodel/schedule/month_picker_viewmodel.dart';

/// 날짜 피커 바텀시트 본문 — 월 네비게이터 + 요일 행 + 날짜 그리드.
///
/// 메인 화면과 독립된 [MonthPickerViewModel] 을 소유한다.
/// - 좌우 화살표: 모달 안 캘린더만 월을 넘긴다 (메인 화면은 그대로).
/// - 날짜 칸 탭: 고른 날짜를 결과로 [Navigator.pop] 한다.
///   메인 화면 반영은 [showAppBottomSheet] 호출부가 그 결과로 처리한다.
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    super.key,
    required this.initialMonth,
    this.filterLeagues = const ['ALL'],
    this.filterTeamIds = const [],
  });

  /// 모달을 열 때 처음 보여줄 월.
  final DateTime initialMonth;

  /// 메인 화면의 리그·팀 필터 — 점 표시가 본문 캘린더와 같은 조건으로 조회되게 한다.
  final List<String> filterLeagues;
  final List<int> filterTeamIds;

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late final MonthPickerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MonthPickerViewModel(
      initialMonth: widget.initialMonth,
      filterLeagues: widget.filterLeagues,
      filterTeamIds: widget.filterTeamIds,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 날짜 칸 탭 → 그 날짜를 결과로 모달을 닫는다.
  void _selectDay(int day) {
    final month = _viewModel.month;
    Navigator.of(context).pop(DateTime(month.year, month.month, day));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 월 네비게이터 — ◁ yyyy.MM ▷ (모달 안에서만 월 이동)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ArrowButton(
                  icon: 'assets/icons/nar-left.svg',
                  scale: scale,
                  onTap: () => _viewModel.shiftMonth(-1),
                ),
                SizedBox(width: 15.5 * scale), // 아이콘 ↔ 텍스트 간격 15.5
                Text(
                  _viewModel.monthLabel,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontWeight: FontWeight.w700,
                    fontSize: 16 * scale,
                    height: 1.5, // line-height 150%
                    letterSpacing: 0,
                    color: AppColors.narTextGnbDefault, // #CED4DA
                  ),
                ),
                SizedBox(width: 15.5 * scale),
                _ArrowButton(
                  icon: 'assets/icons/nar-right.svg',
                  scale: scale,
                  onTap: () => _viewModel.shiftMonth(1),
                ),
              ],
            ),
            SizedBox(height: 24 * scale), // 월 네비게이터 ↔ 요일 행 간격 24
            _WeekdayRow(scale: scale),
            _DayGrid(
              month: _viewModel.month,
              matchDays: _viewModel.matchDays,
              scale: scale,
              onDaySelected: _selectDay,
            ),
          ],
        );
      },
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
///
/// 좌우를 31.5 들여쓰고, 높이 32 안에서 7칸을 균등 분할한다.
/// 칸마다 좌우 12.5 패딩을 주고 텍스트를 가운데 정렬한다.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.scale});

  final double scale;

  static const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 31.5 * scale),
      child: SizedBox(
        height: 32 * scale,
        child: Row(
          children: [
            for (final day in _weekdays)
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
                        height: 1.5, // line-height 24px / font-size 16px
                        letterSpacing: 0,
                        color: AppColors.narTextGnbDefault, // #CED4DA
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

/// 날짜 그리드 — 월요일 시작, 한 칸 40×40.
///
/// 이번 달 날짜만 그리고 이전·다음 달 자리는 빈 칸으로 둔다.
/// 요일 행과 세로가 맞도록 좌우를 똑같이 31.5 들여쓴다.
class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.month,
    required this.matchDays,
    required this.scale,
    required this.onDaySelected,
  });

  final DateTime month;

  /// 경기가 있는 '일(day)' 집합.
  final Set<int> matchDays;
  final double scale;

  /// 날짜 칸 탭 콜백. 인자는 탭한 '일(day)'.
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    // 1일이 속한 주의 월요일까지 거슬러 올라갈 빈 칸 수.
    final firstDay = DateTime(month.year, month.month);
    final leadingDays = firstDay.weekday - DateTime.monday; // 월요일이면 0
    // 이번 달 일수 (다음 달 0일 = 이번 달 말일).
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

  /// [day] 가 이번 달 범위 밖이면 빈 칸(행 높이만 확보), 안이면 날짜 칸.
  Widget _cell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) {
      return SizedBox(height: 40 * scale);
    }
    return Center(
      child: _DayCell(
        day: day,
        hasMatch: matchDays.contains(day),
        scale: scale,
        onTap: () => onDaySelected(day),
      ),
    );
  }
}

/// 날짜 한 칸 — 40×40. 가운데에 날짜 글자, 그 아래 경기 점.
///
/// 경기가 있으면 흰 글자 + 점, 없으면 흐린 글자만. 점 자리는 항상
/// 차지해(없을 땐 투명) 칸마다 글자 세로 위치가 흔들리지 않는다.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasMatch,
    required this.scale,
    required this.onTap,
  });

  final int day;
  final bool hasMatch;
  final double scale;
  final VoidCallback onTap;

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
                height: 1.5, // line-height 24px / font-size 16px
                letterSpacing: 0,
                color: hasMatch
                    ? AppColors.narTextSecondary // 경기 O — #FFFFFF
                    : AppColors.narButtonDisabledText, // 경기 X — #5C5F66
              ),
            ),
            SizedBox(height: 2 * scale),
            // 경기 점 — 4×4 narBg 그라데이션 원.
            Container(
              width: 4 * scale,
              height: 4 * scale,
              decoration: hasMatch
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
