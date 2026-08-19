import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../component/guide_callout.dart';
import '../guide_page_data.dart';

/// 1장 — 마이 구독.
///
/// 무대는 마이구독 화면 목업(`guide-1`) 위에 말풍선 두 개를 얹고, 아래쪽에
/// 하단 네비 목업(`guide-1-2`)을 둔다.
///
/// 말풍선은 위젯으로 그린다 — 디자인 SVG 는 문구까지 path 로 구워져 있어
/// 영어 로케일에서도 한국어가 그대로 남기 때문이다.
GuidePageData guidePage1(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return GuidePageData(
    sectionIcon: 'assets/icons/empty-stars.svg',
    sectionLabel: l.guide1Section,
    sectionStep: 1,
    sectionStepCount: 2,
    headline: l.guide1Headline,
    description: l.guide1Description,
    stageBuilder: (context, scale) => const _Stage(),
  );
}

class _Stage extends StatelessWidget {
  const _Stage();

  /// 하단 네비 목업과 무대 아래 끝(=하단 패널 윗면) 사이 간격.
  static const double _navGap = 20;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 시안은 812 높이 기준 좌표다. 무대 높이가 기기마다 달라지므로 시안의
    // 무대 높이(547)에 대한 비율로 환산해 같은 자리에 놓는다.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageScale = constraints.maxHeight / guideStageDesignHeight;
        final width = constraints.maxWidth;
        // 가로도 시안 폭(375) 기준으로 환산해야 말풍선이 목업의 같은 지점을
        // 가리킨다. 세로와 따로 재는 이유는 기기 화면비가 시안과 다르기 때문.
        final wScale = width / guideDesignWidth;

        return Stack(
          children: [
            // 마이구독 화면 목업 (시안 260×440, top 108).
            Positioned(
              top: 108 * stageScale,
              left: (width - 260 * wScale) / 2,
              child: Image.asset(
                'assets/images/guide/guide-1.png',
                width: 260 * wScale,
                height: 440 * stageScale,
                fit: BoxFit.fill,
              ),
            ),
            // 하단 네비 목업 (시안 300×65). 무대 아래 끝에서 _navGap 위.
            Positioned(
              bottom: _navGap * stageScale,
              left: (width - 300 * wScale) / 2,
              child: Image.asset(
                'assets/images/guide/guide-1-2.png',
                width: 300 * wScale,
                height: 65 * stageScale,
                fit: BoxFit.fill,
              ),
            ),
            // ② 구독 설정 아이콘을 가리킨다 — 꼬리가 위(시안 top 193 의 꼬리 포함 179).
            GuideCallout(
              text: l.guide1CalloutSettings,
              tail: GuideCalloutTail.up,
              tailCenterX: 295,
              tailTipY: 179,
              tailAlignment: 0.901,
              wScale: wScale,
              hScale: stageScale,
            ),
            // ① 마이구독 탭을 가리킨다 — 꼬리가 아래(시안 top 428).
            GuideCallout(
              text: l.guide1CalloutPage,
              tail: GuideCalloutTail.down,
              tailCenterX: 244,
              tailTipY: 479,
              tailAlignment: 0.92,
              wScale: wScale,
              hScale: stageScale,
            ),
          ],
        );
      },
    );
  }
}
