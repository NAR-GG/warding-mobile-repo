import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../component/guide_shadowed_mock.dart';
import '../guide_page_data.dart';

/// 4장 — 마이 페이지(알림 세부 설정).
///
/// 3장과 같은 섹션·문구를 쓰고 무대만 다르다. 말풍선 없이 설정 화면 목업
/// 두 장을 겹쳐 놓는다.
GuidePageData guidePage4(BuildContext context) {
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
    // 시안(375×812)의 무대 높이 547 기준으로 환산한다. 가로·세로를 따로 재는
    // 이유는 기기 화면비가 시안과 달라, 하나로 묶으면 배치가 어긋나기 때문.
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageScale = constraints.maxHeight / guideStageDesignHeight;
        final wScale = constraints.maxWidth / guideDesignWidth;

        return Stack(
          children: [
            // 알림 설정 목록 (시안 248.91×292, left 20, top 128).
            GuideShadowedMock(
              asset: 'assets/images/guide/guide-4.png',
              designWidth: 248.91,
              designHeight: 292,
              designLeft: 20,
              designTop: 128,
              wScale: wScale,
              hScale: stageScale,
            ),
            // 세부 설정 시트 (시안 285×128, left 70, top 389).
            GuideShadowedMock(
              asset: 'assets/images/guide/guide-4-2.png',
              designWidth: 285,
              designHeight: 128,
              designLeft: 70,
              designTop: 389,
              wScale: wScale,
              hScale: stageScale,
            ),
          ],
        );
      },
    );
  }
}
