import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/calendar_week_start.dart';
import '../../../styles/app_colors.dart';
import '../../../viewmodel/mypage/calendar_week_start_viewmodel.dart';
import 'calendar_week_start_sheet.dart';

/// 마이페이지 — 캘린더 시작 요일 설정 섹션 (양옆 20 패딩).
///
/// QuietHours 섹션 바로 아래에 온다. 기기 로컬 설정이라 로그인 여부와 무관하게
/// 항상 보인다(서버 저장이 필요한 QuietHours와 다른 점).
class CalendarWeekStartSection extends StatefulWidget {
  const CalendarWeekStartSection({super.key, this.scale = 1});

  final double scale;

  @override
  State<CalendarWeekStartSection> createState() =>
      _CalendarWeekStartSectionState();
}

class _CalendarWeekStartSectionState extends State<CalendarWeekStartSection> {
  final CalendarWeekStartViewModel _viewModel = CalendarWeekStartViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openSheet() async {
    await showCalendarWeekStartSheet(
      context: context,
      current: _viewModel.weekStart,
      onChanged: _viewModel.setWeekStart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildSection(widget.scale),
    );
  }

  Widget _buildSection(double scale) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.calendarWeekStartSetting,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 17 * scale,
              height: 25 / 17,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 16 * scale),
          _buildCard(scale, l),
        ],
      ),
    );
  }

  Widget _buildCard(double scale, AppLocalizations l) {
    final label = _viewModel.weekStart == CalendarWeekStart.monday
        ? l.calendarWeekStartMonday
        : l.calendarWeekStartSunday;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: _Row(
        label: l.calendarWeekStartRowLabel,
        scale: scale,
        onTap: _openSheet,
        trailing: _ValueChip(label: label, scale: scale),
      ),
    );
  }
}

/// 라벨 + 우측 값 칩 한 행. `quiet_hours_section.dart`의 `_Row`와 동일 스타일.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.trailing,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final Widget trailing;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 5 * scale),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                color: AppColors.narText,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// 값 + chevron. `quiet_hours_section.dart`의 `_TimeValue`와 동일 스타일.
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary,
        border: Border.all(color: AppColors.narLine),
        borderRadius: BorderRadius.circular(6 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              color: AppColors.narTextTertiary,
            ),
          ),
          SizedBox(width: 4 * scale),
          Icon(Icons.chevron_right, size: 16 * scale, color: AppColors.narText2),
        ],
      ),
    );
  }
}
