import 'package:flutter/material.dart';

import '../../../components/app_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../model/community_report.dart';
import '../../../styles/app_colors.dart';

/// `⋯` 메뉴에서 고른 동작.
enum CommunityMoreAction { report, block, edit, delete }

/// `⋯` → 더보기 메뉴. 글과 댓글이 같은 시트를 쓴다.
///
/// 내가 쓴 것([mine])이면 삭제만 뜬다 — 자기 글을 신고하거나 자기를 차단할
/// 일은 없다. 남의 것이면 신고와 차단이 뜨고, 신고를 고르면 이어서
/// [showReportReasonSheet] 로 사유를 받는다. 사유 없이 접수하면 운영자가 왜
/// 신고됐는지 알 수 없어 처리할 수가 없다.
Future<CommunityMoreAction?> showCommunityMoreSheet(
  BuildContext context, {
  required bool mine,
}) {
  final l = AppLocalizations.of(context)!;
  final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;

  return showAppBottomSheet<CommunityMoreAction>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: mine
          ? [
              _MenuRow(
                label: l.communityMoreEdit,
                scale: scale,
                onTap: () =>
                    Navigator.of(context).pop(CommunityMoreAction.edit),
              ),
              _MenuRow(
                label: l.communityMoreDelete,
                scale: scale,
                danger: true,
                onTap: () =>
                    Navigator.of(context).pop(CommunityMoreAction.delete),
              ),
            ]
          : [
              _MenuRow(
                label: l.communityMoreReport,
                scale: scale,
                danger: true,
                onTap: () =>
                    Navigator.of(context).pop(CommunityMoreAction.report),
              ),
              _MenuRow(
                label: l.communityMoreBlock,
                scale: scale,
                onTap: () =>
                    Navigator.of(context).pop(CommunityMoreAction.block),
              ),
            ],
    ),
  );
}

/// 신고 결과 — 사유와 (기타일 때) 사용자가 적은 상세.
///
/// 운영자가 처리하려면 "왜 신고됐는지"를 알아야 한다. 사유 코드만으로 설명이
/// 안 되는 게 기타라, 기타를 고르면 상세를 받는다.
typedef CommunityReportInput = ({CommunityReportReason reason, String? detail});

/// 신고 사유 선택 시트.
Future<CommunityReportInput?> showReportReasonSheet(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  final scale = MediaQuery.of(context).size.width.clamp(320.0, 430.0) / 375;

  return showAppBottomSheet<CommunityReportInput>(
    context: context,
    child: _ReasonPicker(
      title: l.communityReportTitle,
      submitLabel: l.communityReportSubmit,
      etcHint: l.communityReportEtcHint,
      reasons: [
        (value: CommunityReportReason.abuse, label: l.communityReportAbuse),
        (value: CommunityReportReason.obscene, label: l.communityReportObscene),
        (value: CommunityReportReason.ad, label: l.communityReportAd),
        (value: CommunityReportReason.fraud, label: l.communityReportFraud),
        (value: CommunityReportReason.spam, label: l.communityReportSpam),
        (value: CommunityReportReason.etc, label: l.communityReportEtc),
      ],
      scale: scale,
    ),
  );
}

/// 신고 사유 한 줄 — API 로 보낼 코드와 화면에 보일 이름.
typedef _Reason = ({CommunityReportReason value, String label});

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
    required this.etcHint,
    required this.reasons,
    required this.scale,
  });

  final String title;
  final String submitLabel;
  final String etcHint;

  final List<_Reason> reasons;
  final double scale;

  @override
  State<_ReasonPicker> createState() => _ReasonPickerState();
}

class _ReasonPickerState extends State<_ReasonPicker> {
  final TextEditingController _detail = TextEditingController();
  CommunityReportReason? _selected;

  @override
  void initState() {
    super.initState();
    _detail.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  bool get _isEtc => _selected == CommunityReportReason.etc;

  /// 기타는 상세를 적어야 보낼 수 있다. 사유 없이 접수해봐야 운영자가 처리를 못 한다.
  bool get _submittable =>
      _selected != null && (!_isEtc || _detail.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final selected = _selected;

    // 기타를 고르면 입력칸에 포커스가 가며 키보드가 올라온다. 공용 바텀시트는
    // 하단 여백이 고정이라 그대로 두면 시트가 키보드에 가린다. 여기서만 밀어 올린다.
    //
    // 사유 7개 + 입력칸 + 버튼이 키보드가 차지하고 남은 높이를 넘길 수 있어
    // (실측 22px overflow) 스크롤로 받아낸다.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 6 * scale),
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
                onTap: () => setState(() => _selected = reason.value),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10 * scale),
                  child: Row(
                    children: [
                      Icon(
                        reason.value == selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18 * scale,
                        color: reason.value == selected
                            ? AppColors.narChipActive
                            : AppColors.narLine2,
                      ),
                      SizedBox(width: 10 * scale),
                      Text(
                        reason.label,
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
            if (_isEtc) ...[
              SizedBox(height: 4 * scale),
              TextField(
                controller: _detail,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 200,
                cursorColor: AppColors.narViolet3,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 13 * scale,
                  height: 1.5,
                  color: AppColors.narText,
                ),
                decoration: InputDecoration(
                  hintText: widget.etcHint,
                  hintStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 13 * scale,
                    height: 1.5,
                    color: AppColors.narDark300,
                  ),
                  counterStyle: TextStyle(
                    fontSize: 10 * scale,
                    color: AppColors.narDark300,
                  ),
                  filled: true,
                  fillColor: AppColors.narDark600,
                  contentPadding: EdgeInsets.all(11 * scale),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8 * scale),
                    borderSide: const BorderSide(
                      color: AppColors.narLine2,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8 * scale),
                    borderSide: const BorderSide(
                      color: AppColors.narLine2,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8 * scale),
                    borderSide: const BorderSide(
                      color: AppColors.narChipActive,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 8 * scale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _submittable
                  ? () => Navigator.of(context).pop((
                      reason: selected!,
                      detail: _isEtc ? _detail.text.trim() : null,
                    ))
                  : null,
              child: Container(
                height: 48 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _submittable
                      ? AppColors.narButton1Bg
                      : AppColors.narDark500,
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Text(
                  widget.submitLabel,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 15 * scale,
                    height: 1.45,
                    color: _submittable
                        ? AppColors.narButton1Text
                        : AppColors.narButtonDisabledText,
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
