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

  static const LinearGradient narBg = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE87558), Color(0xFFC865C9), Color(0xFF791BB8)],
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
}
