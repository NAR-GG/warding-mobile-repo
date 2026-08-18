import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../component/guide_callout.dart';
import '../guide_page_data.dart';

/// 2장 — 마이 구독(구독 설정).
///
/// 구독 설정 화면 목업(`guide-2`) 위에 말풍선 두 개를 얹는다. 1장과 달리
/// 하단 네비 목업은 없고 말풍선 꼬리가 둘 다 아래를 향한다.
GuidePageData guidePage2(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return GuidePageData(
    sectionIcon: 'assets/icons/empty-stars.svg',
    sectionLabel: l.guide1Section,
    headline: l.guide1Headline,
    description: l.guide2Description,
    stageBuilder: (context, scale) => const _Stage(),
  );
}

class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 시안(375×812)의 무대 높이 547 기준으로 환산한다. 가로·세로를 따로 재는
    // 이유는 기기 화면비가 시안과 달라, 하나로 묶으면 말풍선이 목업의 엉뚱한
    // 지점을 가리키기 때문.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageScale = constraints.maxHeight / guideStageDesignHeight;
        final width = constraints.maxWidth;
        final wScale = width / guideDesignWidth;

        return Stack(
          children: [
            // 구독 설정 화면 목업 (시안 260×439, top 108).
            Positioned(
              top: 108 * stageScale,
              left: (width - 260 * wScale) / 2,
              child: Image.asset(
                'assets/images/guide/guide-2.png',
                width: 260 * wScale,
                height: 439 * stageScale,
                fit: BoxFit.fill,
              ),
            ),
            // ① 자동 구독된 팀을 가리킨다 — 꼬리가 아래(시안 top 209).
            GuideCallout(
              text: l.guide2CalloutAuto,
              tail: GuideCalloutTail.down,
              tailCenterX: 77,
              tailTipY: 259,
              tailAlignment: 0.265,
              horizontalPadding: 16,
              wScale: wScale,
              hScale: stageScale,
            ),
            // ② 추가 구독 설정을 가리킨다 — 꼬리가 아래(시안 top 378).
            GuideCallout(
              text: l.guide2CalloutAdd,
              tail: GuideCalloutTail.down,
              tailCenterX: 285,
              tailTipY: 428,
              tailAlignment: 0.889,
              horizontalPadding: 16,
              wScale: wScale,
              hScale: stageScale,
            ),
          ],
        );
      },
    );
  }
}
