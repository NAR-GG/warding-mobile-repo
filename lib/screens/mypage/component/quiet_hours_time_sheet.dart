import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';

/// 분 선택 간격. 취침 시간에 1분 정밀도는 필요 없고, 서버도 5의 배수만 받는다.
const int kQuietHoursMinuteStep = 5;

/// 알림 잠자기 시각 선택 바텀시트.
///
/// 오전·오후 / 시 / 분 3열 휠. 분은 [kQuietHoursMinuteStep] 간격이라 12행뿐이다.
/// `showTimePicker` 대신 시트를 쓰는 이유는 앱이 바텀시트로 톤을 통일해 뒀기 때문이다.
class QuietHoursTimeSheet extends StatefulWidget {
  const QuietHoursTimeSheet({
    super.key,
    required this.title,
    required this.initial,
  });

  final String title;
  final TimeOfDay initial;

  @override
  State<QuietHoursTimeSheet> createState() => _QuietHoursTimeSheetState();
}

class _QuietHoursTimeSheetState extends State<QuietHoursTimeSheet> {
  /// 0 = 오전, 1 = 오후.
  late int _period;

  /// 12시간제 시(1~12)의 인덱스(0~11).
  late int _hourIndex;

  /// 분 인덱스(0~11) — 값은 인덱스 × [kQuietHoursMinuteStep].
  late int _minuteIndex;

  static const List<int> _hours = [12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

  @override
  void initState() {
    super.initState();
    _period = widget.initial.hour < 12 ? 0 : 1;
    _hourIndex = _hours.indexOf(widget.initial.hour % 12);
    // 5분 배수가 아닌 값이 서버에서 오더라도(구버전 데이터) 가장 가까운 칸에 붙인다.
    _minuteIndex =
        (widget.initial.minute / kQuietHoursMinuteStep).round() % (60 ~/ kQuietHoursMinuteStep);
  }

  TimeOfDay get _selected {
    final base = _hours[_hourIndex] % 12;
    return TimeOfDay(
      hour: _period == 0 ? base : base + 12,
      minute: _minuteIndex * kQuietHoursMinuteStep,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

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
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 18 * scale,
              height: 1.4,
              color: AppColors.narText,
            ),
          ),
        ),
        Container(
          height: 176 * scale,
          decoration: BoxDecoration(
            color: AppColors.narBgTertiary,
            borderRadius: BorderRadius.circular(10 * scale),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 선택 기준선. 없으면 어느 줄이 선택인지 판단할 시각적 기준이 없다.
              IgnorePointer(
                child: Container(
                  height: 38 * scale,
                  margin: EdgeInsets.symmetric(horizontal: 12 * scale),
                  decoration: BoxDecoration(
                    color: AppColors.narDark500,
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                ),
              ),
              _buildWheels(scale, l),
            ],
          ),
        ),
        SizedBox(height: 16 * scale),
        Row(
          children: [
            Expanded(
              child: _SheetButton(
                label: l.cancel,
                onTap: () => Navigator.of(context).pop(),
                scale: scale,
              ),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: _SheetButton(
                label: l.quietHoursSave,
                primary: true,
                onTap: () => Navigator.of(context).pop(_selected),
                scale: scale,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 오전·오후 / 시 / 분 3열.
  Widget _buildWheels(double scale, AppLocalizations l) {
    return Row(
      children: [
        Expanded(
          child: _Wheel(
            initialIndex: _period,
            count: 2,
            labelAt: (i) => i == 0 ? l.quietHoursAm : l.quietHoursPm,
            onChanged: (i) => setState(() => _period = i),
            scale: scale,
          ),
        ),
        Expanded(
          child: _Wheel(
            initialIndex: _hourIndex,
            count: _hours.length,
            labelAt: (i) => '${_hours[i]}',
            onChanged: (i) => setState(() => _hourIndex = i),
            scale: scale,
          ),
        ),
        Expanded(
          child: _Wheel(
            initialIndex: _minuteIndex,
            count: 60 ~/ kQuietHoursMinuteStep,
            labelAt: (i) =>
                (i * kQuietHoursMinuteStep).toString().padLeft(2, '0'),
            onChanged: (i) => setState(() => _minuteIndex = i),
            scale: scale,
          ),
        ),
      ],
    );
  }
}

/// 휠 한 열. 선택된 칸만 흰색·굵게, 나머지는 흐리게.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.initialIndex,
    required this.count,
    required this.labelAt,
    required this.onChanged,
    required this.scale,
  });

  final int initialIndex;
  final int count;
  final String Function(int index) labelAt;
  final ValueChanged<int> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      itemExtent: 38 * scale,
      scrollController: FixedExtentScrollController(initialItem: initialIndex),
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onChanged,
      children: [
        for (var i = 0; i < count; i++)
          Center(
            child: Text(
              labelAt(i),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 19 * scale,
                color: AppColors.narText,
              ),
            ),
          ),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    required this.scale,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final double scale;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44 * scale,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary ? AppColors.narBg : null,
          color: primary ? null : AppColors.narDark500,
          borderRadius: BorderRadius.circular(8 * scale),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 15 * scale,
            color: primary ? AppColors.narText : AppColors.narText3,
          ),
        ),
      ),
    );
  }
}

/// 잠자기 시각 선택 시트를 띄운다. 저장하면 고른 시각, 취소하면 null 을 돌려준다.
Future<TimeOfDay?> showQuietHoursTimeSheet({
  required BuildContext context,
  required String title,
  required TimeOfDay initial,
}) {
  return showAppBottomSheet<TimeOfDay>(
    context: context,
    child: QuietHoursTimeSheet(title: title, initial: initial),
  );
}
