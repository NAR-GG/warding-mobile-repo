import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const Color gary100 = Color(0xFF000000);

  static const Color narDark400 = Color(0xFF373A40);
  static const Color narDark300 = Color(0xFF5C5F66);
  static const Color narDark600 = Color(0xFF25262B);
  static const Color narDark800 = Color(0xFF141517);
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

  static const Color kakaoBg = Color(0xFFFEE500);
  static const Color kakaoText = Color(0xD9000000);

  static const Color naverBg = Color(0xFF03C75A);
  static const Color naverText = Color(0xFFFFFFFF);
  static const Color googleBg = Color(0xFFFFFFFF);

  // nar_button_1 (밝은 버튼)
  static const Color narButton1Bg = Color(0xFFDEE2E6);
  static const Color narButton1Text = Color(0xFF101113);

  // nar_button_2 (어두운 + 테두리 버튼)
  static const Color narButton2Bg = Color(0xFF5C5F66);
  static const Color narButton2Line = Color(0xFF373A40);
  static const Color narButton2Text = Color(0xFFFCFDFE);

  // app_bottom_nav (공용 하단 네비게이션)
  static const Color narNavBg = Color(0xB225262B); // #25262BB2
  static const Color narNavSelectedBg = Color(0x80101113); // #10111380
  static const Color narGray400 = Color(0xFFCED4DA); // 활성 아이콘
  static const Color narDark200 = Color(0xFF909296); // 비활성 아이콘

  // schedule (경기 일정)
  static const Color narBgTertiary = Color(0xFF1F2024); // nar_BG_tertiary
  static const Color narTextGnbDefault = Color(0xFFCED4DA); // nar_text_GNB_default
  static const Color narTextTertiary = Color(0xFFFCFDFE); // nar_text_tertiary
  static const Color narText4 = Color(0xFFA6A7AB); // nar_text_4
  static const Color narTextScore = Color(0xFFF03E3E); // nar_text_score
  static const Color narTextRed = Color(0xFFFF6B6B); // nar_text_red
}
