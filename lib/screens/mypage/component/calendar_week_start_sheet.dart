import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../model/calendar_week_start.dart';
import '../../../styles/app_colors.dart';

/// 마이페이지 캘린더 시작 요일 설정 바텀시트.
///
/// [AppBottomSheet] 안에 월요일/일요일 옵션을 나열한다. 선택하면 [onChanged]로
/// 알리고 시트를 닫는다.
class CalendarWeekStartSheet extends StatelessWidget {
  const CalendarWeekStartSheet({
    super.key,
    required this.current,
    this.onChanged,
  });

  final CalendarWeekStart current;
  final ValueChanged<CalendarWeekStart>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    final options = <(CalendarWeekStart, String)>[
      (CalendarWeekStart.monday, l.calendarWeekStartMonday),
      (CalendarWeekStart.sunday, l.calendarWeekStartSunday),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36 * scale,
            height: 4 * scale,
            margin: EdgeInsets.only(bottom: 20 * scale),
            decoration: BoxDecoration(
              color: AppColors.narDark200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 16 * scale),
          child: Text(
            l.calendarWeekStartSetting,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 18 * scale,
              height: 1.4,
              color: AppColors.narText,
            ),
          ),
        ),
        ...options.map((option) {
          final (value, label) = option;
          final isSelected = value == current;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              onChanged?.call(value);
              Navigator.of(context).pop();
            },
            child: Container(
              height: 48 * scale,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.narBgTertiary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15 * scale,
                  height: 1.55,
                  color: isSelected
                      ? AppColors.narText
                      : AppColors.narTextTertiary,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// [CalendarWeekStartSheet] 를 [AppBottomSheet] 모달로 띄우는 헬퍼.
Future<void> showCalendarWeekStartSheet({
  required BuildContext context,
  required CalendarWeekStart current,
  ValueChanged<CalendarWeekStart>? onChanged,
}) {
  return showAppBottomSheet(
    context: context,
    child: CalendarWeekStartSheet(current: current, onChanged: onChanged),
  );
}
