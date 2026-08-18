import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../component/guide_callout.dart';
import '../guide_page_data.dart';

/// 3장 — 마이 페이지(알림 설정).
///
/// 마이페이지 화면 목업(`guide-3`) 위에 말풍선 두 개를 얹고, 아래쪽에 하단
/// 네비 목업(`guide-3-2`)을 둔다.
GuidePageData guidePage3(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return GuidePageData(
    sectionIcon: 'assets/icons/user.svg',
    sectionLabel: l.guide3Section,
    headline: l.guide3Headline,
    description: l.guide3Description,
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
            // 마이페이지 화면 목업 (시안 260×439, top 108).
            Positioned(
              top: 108 * stageScale,
              left: (width - 260 * wScale) / 2,
              child: Image.asset(
                'assets/images/guide/guide-3.png',
                width: 260 * wScale,
                height: 439 * stageScale,
                fit: BoxFit.fill,
              ),
            ),
            // 하단 네비 목업 (시안 297.78×64, top 464). 시안이 가운데에서
            // 2.39 오른쪽으로 밀어 둔 것을 그대로 반영한다.
            Positioned(
              top: 464 * stageScale,
              left: (width - 297.78 * wScale) / 2 + 2.39 * wScale,
              child: Image.asset(
                'assets/images/guide/guide-3-2.png',
                width: 297.78 * wScale,
                height: 64 * stageScale,
                fit: BoxFit.fill,
              ),
            ),
            // ② 화면설정 > 마이구독을 가리킨다 — 꼬리가 아래(시안 top 328).
            GuideCallout(
              text: l.guide3CalloutDisplay,
              tail: GuideCalloutTail.down,
              tailCenterX: 138,
              tailTipY: 378,
              tailAlignment: 0.101,
              wScale: wScale,
              hScale: stageScale,
            ),
            // ① 하단 네비의 마이페이지 탭을 가리킨다 — 꼬리가 아래(시안 top 430).
            GuideCallout(
              text: l.guide3CalloutMypage,
              tail: GuideCalloutTail.down,
              tailCenterX: 310,
              tailTipY: 480,
              tailAlignment: 0.869,
              wScale: wScale,
              hScale: stageScale,
            ),
          ],
        );
      },
    );
  }
}
