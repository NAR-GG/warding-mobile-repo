import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/community_draft.dart';
import '../../../styles/app_colors.dart';

/// 임시저장 목록 바텀시트. 행을 탭하면 그 드래프트로 pop, 삭제 아이콘은 시트를
/// 닫지 않고 목록에서만 뺀다.
Future<CommunityDraft?> showCommunityDraftSheet(
  BuildContext context, {
  required List<CommunityDraft> drafts,
  required Future<void> Function(int id) onDelete,
}) {
  return showModalBottomSheet<CommunityDraft>(
    context: context,
    backgroundColor: AppColors.narBgSecondary,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CommunityDraftSheet(drafts: drafts, onDelete: onDelete),
  );
}

class _CommunityDraftSheet extends StatefulWidget {
  const _CommunityDraftSheet({required this.drafts, required this.onDelete});

  final List<CommunityDraft> drafts;
  final Future<void> Function(int id) onDelete;

  @override
  State<_CommunityDraftSheet> createState() => _CommunityDraftSheetState();
}

class _CommunityDraftSheetState extends State<_CommunityDraftSheet> {
  late final List<CommunityDraft> _drafts = List.of(widget.drafts);

  Future<void> _delete(CommunityDraft draft) async {
    final id = draft.id;
    if (id == null) return;
    await widget.onDelete(id);
    if (!mounted) return;
    setState(() => _drafts.removeWhere((d) => d.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final scale = media.size.width.clamp(320.0, 430.0) / 375;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20 * scale,
                  18 * scale,
                  20 * scale,
                  12 * scale,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.communityDraftListTitle,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          fontSize: 17 * scale,
                          color: AppColors.narText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.narLine),
              Flexible(
                child: _drafts.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 40 * scale),
                        child: Text(
                          l.communityDraftEmptyList,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13 * scale,
                            color: AppColors.narDark300,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 4 * scale),
                        itemCount: _drafts.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.narLine),
                        itemBuilder: (_, i) => _row(l, scale, _drafts[i]),
                      ),
              ),
              SizedBox(height: 8 * scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(AppLocalizations l, double scale, CommunityDraft draft) {
    final title = draft.title.trim().isEmpty
        ? l.communityDraftUntitled
        : draft.title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(draft),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20 * scale,
          vertical: 12 * scale,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: 14 * scale,
                            color: AppColors.narText,
                          ),
                        ),
                      ),
                      if (draft.editPostId != null) ...[
                        SizedBox(width: 6 * scale),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6 * scale,
                            vertical: 2 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.narChipBadgeBg,
                            borderRadius: BorderRadius.circular(4 * scale),
                          ),
                          child: Text(
                            l.communityDraftEditingBadge,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              fontSize: 10 * scale,
                              color: AppColors.narViolet3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 3 * scale),
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(draft.savedAt),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11 * scale,
                      color: AppColors.narText3,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _delete(draft),
              child: Padding(
                padding: EdgeInsets.all(8 * scale),
                child: Icon(
                  Icons.delete_outline,
                  size: 18 * scale,
                  color: AppColors.narDark300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
