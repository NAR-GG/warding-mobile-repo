import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../component/guide_shadowed_mock.dart';
import '../guide_page_data.dart';

/// 5장 — 마이 페이지(일반 설정).
///
/// 방해 금지 모드·캘린더 시작 요일 등 설정 항목 목업 세 장을 계단식으로
/// 겹쳐 놓는다. 3·4장과 같은 '마이 페이지' 섹션이지만 문구는 다르다.
GuidePageData guidePage5(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return GuidePageData(
    sectionIcon: 'assets/icons/user.svg',
    sectionLabel: l.guide3Section,
    headline: l.guide5Headline,
    description: l.guide5Description,
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

        // 시안의 쌓임 순서(image 282 → 284 → 283)를 그대로 따른다.
        return Stack(
          children: [
            // 방해 금지 모드 (시안 305.15×68, left 20, top 163).
            GuideShadowedMock(
              asset: 'assets/images/guide/guide-5.png',
              designWidth: 305.15,
              designHeight: 68,
              designLeft: 20,
              designTop: 163,
              wScale: wScale,
              hScale: stageScale,
            ),
            // 캘린더 시작 요일 (시안 292×68, left 64, top 248).
            GuideShadowedMock(
              asset: 'assets/images/guide/guide-5-2.png',
              designWidth: 292,
              designHeight: 68,
              designLeft: 64,
              designTop: 248,
              wScale: wScale,
              hScale: stageScale,
            ),
            // 설정 시트 (시안 292×123, left 15, top 333).
            GuideShadowedMock(
              asset: 'assets/images/guide/guide-5-3.png',
              designWidth: 292,
              designHeight: 123,
              designLeft: 15,
              designTop: 333,
              wScale: wScale,
              hScale: stageScale,
            ),
          ],
        );
      },
    );
  }
}
