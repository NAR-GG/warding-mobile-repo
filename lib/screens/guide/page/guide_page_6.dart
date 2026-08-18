import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../guide_page_data.dart';

/// 6장 — 위젯 소개.
///
/// 다른 장과 달리 섹션 아이콘이 없고, 설명 아래 연출 고지 주석이 붙는다.
/// 무대는 홈 화면 목업 한 장뿐이다.
GuidePageData guidePage6(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return GuidePageData(
    sectionLabel: l.guide6Section,
    headline: l.guide6Headline,
    description: l.guide6Description,
    footnote: l.guide6Footnote,
    stageBuilder: (context, scale) => const _Stage(),
  );
}

class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    // 시안(375×812)의 무대 높이 547 기준으로 환산한다. 가로·세로를 따로 재는
    // 이유는 기기 화면비가 시안과 달라, 하나로 묶으면 배치가 어긋나기 때문.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageScale = constraints.maxHeight / guideStageDesignHeight;
        final wScale = constraints.maxWidth / guideDesignWidth;

        // 시안 이미지(258×559, top 108)는 무대(547)보다 20 만큼 길어 하단
        // 패널 위로 흘러넘친다. 무대는 잘라 내지 않고(clipBehavior: none)
        // 그대로 두면 아래 패널이 그 위에 얹혀 시안처럼 잘려 보인다.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 108 * stageScale,
              left: 59 * wScale,
              child: Image.asset(
                'assets/images/guide/guide-6.png',
                width: 258 * wScale,
                height: 559 * stageScale,
                fit: BoxFit.fill,
              ),
            ),
          ],
        );
      },
    );
  }
}
