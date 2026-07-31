import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const Color gray100 = Color(0xFF000000);

  static const Color narDark400 = Color(0xFF373A40);
  static const Color narDark500 = Color(0xFF2C2E33); // nar_dark_500
  static const Color narDark300 = Color(0xFF5C5F66);
  static const Color narDark600 = Color(0xFF25262B);
  static const Color narDark800 = Color(0xFF141517);
  static const Color narGray500 = Color(0xFFADB5BD); // gray/5

  static const Color narText = Color(0xFFFFFFFF);
  static const Color narText2 = Color(0xFFA6A7AB);
  static const Color narLine2 = Color(0xFF495057);
  static const Color narLine = Color(0xFF343A40); // nar_line

  static const LinearGradient narBg = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE87558), Color(0xFFC865C9), Color(0xFF791BB8)],
    stops: [0.0076, 0.5153, 1.0],
  );

  /// 오늘 날짜 칸 배경 — narBg 그라데이션을 8% 불투명도(0x14)로.
  static const LinearGradient narTodayBg = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x14E87558), Color(0x14C865C9), Color(0x14791BB8)],
    stops: [0.0076, 0.5153, 1.0],
  );

  /// 선수 평점 안내 배너 배경 — narBg 그라데이션을 20% 불투명도(0x33)로.
  static const LinearGradient narRatingBannerBg = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x33E87558), Color(0x33C865C9), Color(0x33791BB8)],
    stops: [0.0076, 0.5153, 1.0],
  );

  /// 라이브 이벤트 타임라인 세로선 — narBg 색을 세로(위→아래) 방향으로.
  static const LinearGradient narTimelineLine = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE87558), Color(0xFFC865C9), Color(0xFF791BB8)],
    stops: [0.0076, 0.5153, 1.0],
  );

  static const Color kakaoBg = Color(0xFFFEE500);
  static const Color kakaoText = Color(0xD9000000);

  static const Color naverBg = Color(0xFF03C75A);
  static const Color naverText = Color(0xFFFFFFFF);

  /// 중계 플랫폼 브랜드색 — 중계 채널 선택 시트의 로고 칩에 쓴다.
  static const Color chzzkBrand = Color(0xFF00FFA3);
  static const Color soopBrand = Color(0xFF6E9BFF);
  static const Color googleBg = Color(0xFFFFFFFF);
  static const Color appleBg = Color(0xFFFFFFFF);

  // nar_button_1 (밝은 버튼)
  static const Color narButton1Bg = Color(0xFFDEE2E6);
  static const Color narButton1Text = Color(0xFF101113);

  // nar_button_2 (어두운 + 테두리 버튼)
  static const Color narButton2Bg = Color(0xFF5C5F66);
  static const Color narButton2Line = Color(0xFF373A40);
  static const Color narButton2Text = Color(0xFFFCFDFE);

  // app_bottom_nav (공용 하단 네비게이션)
  static const Color narNavBg = Color(0x3D25262B); // rgba(37,38,43,0.24)
  static const Color narNavSelectedBg = Color(0x80101113); // rgba(16,17,19,0.5)
  static const Color narGray400 = Color(0xFFCED4DA); // 활성 아이콘·텍스트
  static const Color narDark200 = Color(0xFF909296); // 비활성 아이콘

  // bottom sheet (공용 바텀시트 모달)
  static const Color narBgSecondary = Color(0xFF1A1B1E); // nar_BG_secondary
  static const Color narBottomSheetShadow = Color(0x1F101113); // #1011131F

  // month picker (날짜 피커 모달)
  static const Color narButtonDisabledText = Color(
    0xFF5C5F66,
  ); // nar_button_disabled_text
  static const Color narTextSecondary = Color(0xFFFFFFFF); // nar_text_secondary

  // select box / labeled field (공용 입력)
  static const Color narBgLast = Color(0xFF25262B); // nar_BG_last
  static const Color narText3 = Color(0xFFC1C2C5); // nar_text_3
  static const Color narRedOpacity25 = Color(0x40FA5252); // nar_red_opacity25

  // schedule (경기 일정)
  static const Color narBgTertiary = Color(0xFF1F2024); // nar_BG_tertiary
  static const Color narTextGnbDefault = Color(
    0xFFCED4DA,
  ); // nar_text_GNB_default
  static const Color narTextTertiary = Color(0xFFFCFDFE); // nar_text_tertiary
  static const Color narText4 = Color(0xFFA6A7AB); // nar_text_4
  static const Color narTextScore = Color(0xFFF03E3E); // nar_text_score
  static const Color narTextRed = Color(0xFFFF6B6B); // nar_text_red

  // search select box (공용 검색 선택 박스)
  static const Color narRed500 = Color(0xFFFF6B6B); // nar_red_500
  static const Color narTextTertiarySub = Color(
    0xFFA6A7AB,
  ); // nar_text_tertiary_sub
  static const Color narSearchSelectShadow = Color(0x0A000000); // #0000000A

  // chip (공용 선택 칩)
  static const Color narChipSelectedBg = Color(
    0x807048E8,
  ); // rgba(112,72,232,0.5)
  static const Color narChipActive = Color(0xFF7048E8); // 활성 필터칩 보더·텍스트
  static const Color narChipBadgeBg = Color(
    0x4D7048E8,
  ); // rgba(112,72,232,0.3) — 선택 수 배지 배경

  // live match card (라이브 경기 카드 / 라이브 칩)
  static const Color liveBadgeBg = Color(0x1AE03131); // rgba(224,49,49,0.1)
  static const Color liveAccent = Color(0xFFE03131); // 점/LIVE 텍스트
  static const Color liveSideBorder = Color(0xFFDB6F47); // 카드 왼쪽 3px
  static const Color scoreWin = Color(0xFFFA5252); // 라이브 승자 스코어

  // live badge — light (경기 상세 헤더용 LIVE 뱃지: red/0 배경 + red/3 보더)
  static const Color liveBadgeLightBg = Color(0xFFFFF5F5); // red/0
  static const Color liveBadgeLightBorder = Color(0xFFFFA8A8); // red/3

  // side badge (진영 BLUE/RED 라이트 톤 보더 + 진한 텍스트)
  static const Color sideBlueBorder = Color(0xFF91A7FF); // indigo/3
  static const Color sideBlueText = Color(0xFF3B5BDB); // indigo/8
  static const Color sideRedBorder = Color(0xFFFFA8A8); // red/3
  static const Color sideRedText = Color(0xFFE03131); // red/8

  // 경기 상세 스코어 (승자: red/7, 패자: gray/1, 콜론: narText2)
  static const Color scoreTextSub = Color(0xFFF1F3F5); // gray/1

  // 경기 상세 콘텐츠 영역 배경 (탭 콘텐츠 #101113)
  static const Color narBgContent = Color(0xFF101113);

  // 최근 상태 로드 버튼 (라이브 이벤트)
  static const Color narGray100 = Color(0xFFF1F3F5); // gray/1

  // 라이브 이벤트 타임라인 (가장 최근 이벤트 강조)
  static const Color narPink700 = Color(0xFFD6336C); // mantine pink/7

  // 플레이한 챔프 카드 (선수 평점 상세)
  static const Color narPlayedChampBg = Color(0xFFFFFFFF); // 카드 배경(선수 이미지 자리)

  /// 플레이한 챔프 카드 하단 inset 그림자 — inset 0 -63px 60px rgba(20,21,23,0.62).
  /// inset shadow를 표현 못 하므로 하단을 어둡게 덮는 세로 그라데이션으로 근사한다.
  static const LinearGradient narPlayedChampOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00141517), Color(0x9E141517)],
    stops: [0.15, 1.0],
  );

  // 평점 분포 (선수 평점 상세) — 별점·분포 바 채움 노랑.
  static const Color narYellow6 = Color(0xFFFAB005); // yellow/6

  // 구독 버튼 (미구독) — narButton1Bg(#DEE2E6) 의 90% 불투명도.
  static const Color narSubscribeBg = Color(0xE6DEE2E6);

  // 공용 입력 필드 — 기본 테두리(#424242).
  static const Color narInputBorder = Color(0xFF424242);

  // 공지 본문 인라인 링크 (다크 배경 위 blue/3).
  static const Color narLinkText = Color(0xFF74C0FC);
}
