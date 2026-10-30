import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../community_rules.dart';
import 'community_rules_sheet.dart';

/// 규칙 요약 + 전문 보기. 본문 아래에 연하게 깔아 방해하지 않되, 스크롤하면
/// 반드시 지나가도록 둔다.
class PostWriteRules extends StatelessWidget {
  const PostWriteRules({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showCommunityRulesSheet(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 9 * scale,
            ),
            decoration: BoxDecoration(
              color: AppColors.narDark600,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.communityRulesSeeAll,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * scale,
                    height: 1.45,
                    color: AppColors.narText3,
                  ),
                ),
                SizedBox(width: 4 * scale),
                Icon(
                  Icons.chevron_right,
                  size: 15 * scale,
                  color: AppColors.narText3,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12 * scale),
        Text(
          kCommunityRulesSummary.trim(),
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 12 * scale,
            height: 1.7,
            color: AppColors.narDark300,
          ),
        ),
      ],
    );
  }
}
