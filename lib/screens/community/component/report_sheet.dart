import 'package:flutter/material.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';

/// `⋯` 메뉴에서 고른 동작.
enum CommunityMoreAction { report, block }

/// `⋯` → 더보기 메뉴. 글과 댓글이 같은 시트를 쓴다.
///
/// 신고를 고르면 이어서 [showReportReasonSheet] 로 사유를 받는다. 사유 없이
/// 신고를 받으면 운영자가 왜 신고됐는지 알 수 없어 처리할 수가 없다.
Future<CommunityMoreAction?> showCommunityMoreSheet(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;

  return showAppBottomSheet<CommunityMoreAction>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuRow(
          label: l.communityMoreReport,
          scale: scale,
          danger: true,
          onTap: () => Navigator.of(context).pop(CommunityMoreAction.report),
        ),
        _MenuRow(
          label: l.communityMoreBlock,
          scale: scale,
          onTap: () => Navigator.of(context).pop(CommunityMoreAction.block),
        ),
      ],
    ),
  );
}

/// 신고 사유 선택 시트. 사유를 고르고 등록하면 그 사유 문자열을 반환한다.
Future<String?> showReportReasonSheet(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;
  final reasons = [
    l.communityReportAbuse,
    l.communityReportSpam,
    l.communityReportSpoiler,
    l.communityReportEtc,
  ];

  return showAppBottomSheet<String>(
    context: context,
    child: _ReasonPicker(
      title: l.communityReportTitle,
      submitLabel: l.communityReportSubmit,
      reasons: reasons,
      scale: scale,
    ),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.scale,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final double scale;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14 * scale),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 15 * scale,
            height: 1.45,
            color: danger ? AppColors.narTextRed : AppColors.narText,
          ),
        ),
      ),
    );
  }
}

class _ReasonPicker extends StatefulWidget {
  const _ReasonPicker({
    required this.title,
    required this.submitLabel,
    required this.reasons,
    required this.scale,
  });

  final String title;
  final String submitLabel;
  final List<String> reasons;
  final double scale;

  @override
  State<_ReasonPicker> createState() => _ReasonPickerState();
}

class _ReasonPickerState extends State<_ReasonPicker> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final selected = _selected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8 * scale),
          child: Text(
            widget.title,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 16 * scale,
              height: 1.45,
              color: AppColors.narText,
            ),
          ),
        ),
        for (final reason in widget.reasons)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selected = reason),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 11 * scale),
              child: Row(
                children: [
                  Icon(
                    reason == selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18 * scale,
                    color: reason == selected
                        ? AppColors.narChipActive
                        : AppColors.narLine2,
                  ),
                  SizedBox(width: 10 * scale),
                  Text(
                    reason,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 14 * scale,
                      height: 1.45,
                      color: AppColors.narText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: 10 * scale),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selected == null
              ? null
              : () => Navigator.of(context).pop(selected),
          child: Container(
            height: 48 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected == null
                  ? AppColors.narDark500
                  : AppColors.narButton1Bg,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Text(
              widget.submitLabel,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 15 * scale,
                height: 1.45,
                color: selected == null
                    ? AppColors.narButtonDisabledText
                    : AppColors.narButton1Text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
