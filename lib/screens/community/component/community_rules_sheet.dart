import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';
import '../community_rules.dart';

/// 커뮤니티 이용규칙 전문. 화면을 거의 꽉 채우는 모달로 띄운다.
///
/// 바텀시트가 아니라 [showDialog] 인 이유: 규칙은 길어서 어차피 전체 높이를 쓰고,
/// 위에서 아래로 읽는 문서라 시트처럼 손잡이를 잡고 끌어내리는 제스처가
/// 스크롤과 싸운다. 상단 여백만 남기고 꽉 채운 뒤 닫기는 X 로만 받는다.
Future<void> showCommunityRulesSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.narDark800.withValues(alpha: 0.6),
    builder: (_) => const _RulesDialog(),
  );
}

class _RulesDialog extends StatelessWidget {
  const _RulesDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final scale = media.size.width.clamp(320.0, 430.0) / 375;

    return Dialog(
      insetPadding: EdgeInsets.only(top: media.padding.top + 24 * scale),
      backgroundColor: AppColors.narBgSecondary,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20 * scale)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              20 * scale,
              18 * scale,
              12 * scale,
              12 * scale,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.communityRulesTitle,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                      fontSize: 17 * scale,
                      height: 1.4,
                      color: AppColors.narText,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: EdgeInsets.all(8 * scale),
                    child: Icon(
                      Icons.close,
                      size: 22 * scale,
                      color: AppColors.narText3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.narLine),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20 * scale,
                16 * scale,
                20 * scale,
                media.padding.bottom + 28 * scale,
              ),
              children: _blocks(kCommunityRulesFull, scale),
            ),
          ),
        ],
      ),
    );
  }

  /// `## ` 로 시작하는 줄은 소제목, 나머지 문단은 본문으로 그린다.
  /// 마크다운 렌더러를 붙일 만한 문법이 아니라(제목 한 종류가 전부) 직접 나눈다.
  static List<Widget> _blocks(String source, double scale) {
    final widgets = <Widget>[];

    for (final raw in source.trim().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) {
        widgets.add(SizedBox(height: 10 * scale));
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 18 * scale, bottom: 6 * scale),
            child: Text(
              line.substring(3),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                fontSize: 16 * scale,
                height: 1.45,
                color: AppColors.narText,
              ),
            ),
          ),
        );
        continue;
      }
      widgets.add(
        Text(
          line,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 13.5 * scale,
            height: 1.65,
            color: AppColors.narText3,
          ),
        ),
      );
    }
    return widgets;
  }
}
