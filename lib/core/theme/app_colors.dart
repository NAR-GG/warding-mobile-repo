// GENERATED — design_tokens/build.mjs 가 만든다. 직접 고치지 않는다.
// 값을 바꾸려면 design_tokens/source/*.json 을 고치고 `pnpm tokens:build`.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color gray100 = Color(0xFF000000);
  static const Color narDark400 = Color(0xFF373A40);
  static const Color narDark500 = Color(0xFF2C2E33); // nar_dark_500
  static const Color narDark300 = Color(0xFF5C5F66);
  static const Color narDark600 = Color(0xFF25262B);
  static const Color narDark800 = Color(0xFF141517);
  /// nar_dark_opacity62 — narDark800 62%. 시안의 인너 섀도우 색.
  static const Color narDarkOpacity62 = Color(0x9E141517);
  static const Color narGray500 = Color(0xFFADB5BD); // gray/5
  static const Color narText = Color(0xFFFFFFFF);
  static const Color narText2 = Color(0xFFA6A7AB);
  static const Color narLine2 = Color(0xFF495057);
  static const Color narLine = Color(0xFF343A40); // nar_line
  static const Color kakaoBg = Color(0xFFFEE500);
  static const Color kakaoText = Color(0xD9000000);
  static const Color naverBg = Color(0xFF03C75A);
  static const Color naverText = Color(0xFFFFFFFF);
  /// 중계 플랫폼 브랜드색 — 중계 채널 선택 시트의 로고 칩에 쓴다.
  static const Color chzzkBrand = Color(0xFF00FFA3);
  static const Color soopBrand = Color(0xFF6E9BFF);
  static const Color googleBg = Color(0xFFFFFFFF);
  static const Color appleBg = Color(0xFFFFFFFF);
  static const Color narButton1Bg = Color(0xFFDEE2E6);
  static const Color narButton1Text = Color(0xFF101113);
  static const Color narButton2Bg = Color(0xFF5C5F66);
  static const Color narButton2Line = Color(0xFF373A40);
  static const Color narButton2Text = Color(0xFFFCFDFE);
  /// rgba(37,38,43,0.5)
  static const Color narNavBg = Color(0x8025262B);
  /// rgba(16,17,19,0.5)
  static const Color narNavSelectedBg = Color(0x80101113);
  /// 활성 아이콘·텍스트
  static const Color narGray400 = Color(0xFFCED4DA);
  /// 비활성 아이콘
  static const Color narDark200 = Color(0xFF909296);
  /// nar_BG_secondary
  static const Color narBgSecondary = Color(0xFF1A1B1E);
  /// #1011131F
  static const Color narBottomSheetShadow = Color(0x1F101113);
  static const Color narPopupBarrier = Color(0xB3000000);
  /// 가이드 배경 위에 덮는 보라 오버레이. rgba(112,72,232,0.25)
  static const Color narGuideOverlay = Color(0x407048E8);
  /// 설명 말풍선 배경.
  static const Color narGuideCallout = Color(0xFF2B02A4);
  /// 하단 패널의 강조 텍스트·아이콘(섹션명, 페이지 표시).
  static const Color narGuideAccent = Color(0xFFEAC5FF);
  static const Color narButtonDisabledText = Color(0xFF5C5F66);
  static const Color narTextSecondary = Color(0xFFFFFFFF); // nar_text_secondary
  /// nar_BG_last
  static const Color narBgLast = Color(0xFF25262B);
  static const Color narText3 = Color(0xFFC1C2C5); // nar_text_3
  static const Color narRedOpacity25 = Color(0x40FA5252); // nar_red_opacity25
  /// nar_BG_tertiary
  static const Color narBgTertiary = Color(0xFF1F2024);
  static const Color narTextGnbDefault = Color(0xFFCED4DA);
  static const Color narTextTertiary = Color(0xFFFCFDFE); // nar_text_tertiary
  static const Color narText4 = Color(0xFFA6A7AB); // nar_text_4
  static const Color narTextScore = Color(0xFFF03E3E); // nar_text_score
  static const Color narTextRed = Color(0xFFFF6B6B); // nar_text_red
  static const Color narRed500 = Color(0xFFFF6B6B); // nar_red_500
  static const Color narTextTertiarySub = Color(0xFFA6A7AB);
  /// #0000000A
  static const Color narSearchSelectShadow = Color(0x0A000000);
  static const Color narChipSelectedBg = Color(0x807048E8);
  /// 활성 필터칩 보더·텍스트
  static const Color narChipActive = Color(0xFF7048E8);
  static const Color narChipBadgeBg = Color(0x4D7048E8);
  /// rgba(0,0,0,0.6)
  static const Color narAdBadgeBg = Color(0x99000000);
  /// rgba(255,255,255,0.8)
  static const Color narAdBadgeText = Color(0xCCFFFFFF);
  /// rgba(224,49,49,0.1)
  static const Color liveBadgeBg = Color(0x1AE03131);
  /// 점/LIVE 텍스트
  static const Color liveAccent = Color(0xFFE03131);
  /// 카드 왼쪽 3px
  static const Color liveSideBorder = Color(0xFFDB6F47);
  /// 라이브 승자 스코어
  static const Color scoreWin = Color(0xFFFA5252);
  static const Color liveBadgeLightBg = Color(0xFFFFF5F5); // red/0
  static const Color liveBadgeLightBorder = Color(0xFFFFA8A8); // red/3
  static const Color sideBlueBorder = Color(0xFF91A7FF); // indigo/3
  static const Color sideBlueText = Color(0xFF3B5BDB); // indigo/8
  static const Color sideRedBorder = Color(0xFFFFA8A8); // red/3
  static const Color sideRedText = Color(0xFFE03131); // red/8
  static const Color scoreTextSub = Color(0xFFF1F3F5); // gray/1
  static const Color narBgContent = Color(0xFF101113);
  static const Color narGray100 = Color(0xFFF1F3F5); // gray/1
  static const Color narPink700 = Color(0xFFD6336C); // mantine pink/7
  /// 카드 배경(선수 이미지 자리)
  static const Color narPlayedChampBg = narDark800;
  /// 스포방지 오버레이 배경 — 시안의 narDark800 40%.
  /// 
  /// 아래 더미 스코어가 이 반투명 너머로 흐릿하게 비쳐야 하므로 불투명으로
  /// 바꾸지 않는다(흐림 자체는 더미 쪽 ImageFiltered 가 만든다).
  static const Color narSpoilerOverlayBg = Color(0x66141517);
  static const Color narYellow6 = Color(0xFFFAB005); // yellow/6
  static const Color narSubscribeBg = Color(0xE6DEE2E6);
  static const Color narInputBorder = Color(0xFF424242);
  static const Color narLinkText = Color(0xFF74C0FC);
  static const Color narSpoilerKnobOff = Color(0x66141517);
  /// 스포방지 토글 트랙 inset 그림자 — inset 0 2px 4px rgba(0,0,0,0.14).
  static const Color narSpoilerTrackShadow = Color(0x24000000);
  static const Color narViolet3 = Color(0xFFB197FC); // mantine violet/3
  static const Color narGreenWin = Color(0xFF34C759);
  /// rgba(20,21,23,0.4) — KDA·CS·GOLD 등 통계 바 배경.
  static const Color narBuildStatsBg = Color(0x66141517);
  /// rgba(255,255,255,0.15) — 아이템·룬·능력치 칩 보더.
  static const Color narWhiteBorder15 = Color(0x26FFFFFF);
  /// rgba(255,255,255,0.62) — 룬 트리 헤더(결의/영감 등) 왼쪽 보더.
  static const Color narWhiteBorder62 = Color(0x9EFFFFFF);
  /// 솔랭 강조 테두리 — narBg 가운데 색(#C865C9) 60%.
  static const Color narSoloLine = Color(0x99C865C9);
  /// 솔랭 강조 글자 — narBg 가운데 색을 밝힌 핑크.
  static const Color narSoloText = Color(0xFFF3BEDC);
  /// 솔랭 진행 중 점.
  static const Color narSoloDot = Color(0xFFE9A0C8);
  /// 솔랭 히어로 카드 스플래시 아래 바탕 — 목업 #1B1C21.
  static const Color narSoloHeroBg = Color(0xFF1B1C21);
  /// 쇼츠 "내 팀" 배지 배경 — 흰색 14%.
  static const Color narWhite14 = Color(0x24FFFFFF);
  /// 블루 진영.
  static const Color matchTeamBlue = Color(0xFF1971C2);
  /// 레드 진영. [narTextScore] 와 같은 값이지만 의미가 달라 따로 둔다 —
  /// 점수 텍스트 색이 바뀌어도 진영 색은 그대로여야 한다.
  static const Color matchTeamRed = Color(0xFFF03E3E);
  /// 라이브 이벤트 스켈레톤 흐름의 밝은 쪽. [narBgSecondary] 에서 밝아진다.
  static const Color narGray600 = Color(0xFF727784);

  static const LinearGradient narBg = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE87558), Color(0xFFC865C9), Color(0xFF791BB8)],
    stops: [0.0076, 0.5153, 1],
  );

  static const LinearGradient narTodayBg = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x14E87558), Color(0x14C865C9), Color(0x14791BB8)],
    stops: [0.0076, 0.5153, 1],
  );

  static const LinearGradient narRatingBannerBg = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x33E87558), Color(0x33C865C9), Color(0x33791BB8)],
    stops: [0.0076, 0.5153, 1],
  );

  static const LinearGradient narTimelineLine = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE87558), Color(0xFFC865C9), Color(0xFF791BB8)],
    stops: [0.0076, 0.5153, 1],
  );

  static const LinearGradient narFadeLine = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFFFFF), Color(0xFF141517)],
  );

  static const LinearGradient narPlayedChampOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00141517), Color(0x52141517), Color(0xB3141517)],
    stops: [0, 0.45, 1],
  );

  static const LinearGradient narSoloTint = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x4DE87558), Color(0x42C865C9), Color(0x4D791BB8)],
  );

  static const LinearGradient narSoloTintSoft = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x24E87558), Color(0x1FC865C9), Color(0x24791BB8)],
  );

  static const LinearGradient narShortsScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xB80B0C0E), Color(0x000B0C0E)],
    stops: [0, 0.38],
  );

}
