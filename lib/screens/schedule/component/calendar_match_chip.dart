import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import 'calendar_match.dart';

/// 경기 칩 — 50×18, 라운드 8, 1px 테두리. 안에 [홈팀] vs [원정팀].
class CalendarMatchChip extends StatelessWidget {
  const CalendarMatchChip({
    super.key,
    required this.match,
    required this.scale,
  });

  final CalendarMatch match;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50 * scale,
      height: 18 * scale,
      padding: EdgeInsets.symmetric(horizontal: 1 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary, // #1F2024
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: AppColors.narLine, width: 1), // #343A40
      ),
      child: Row(
        children: [
          Expanded(child: _teamName(match.home)),
          _vsLabel(),
          Expanded(child: _teamName(match.away)),
        ],
      ),
    );
  }

  Widget _teamName(String name) {
    // 세 글자 팀 코드(BFX, GEN, HLE)가 잘리지 않도록 넘치면 글자를 축소한다.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        name,
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w400, // Regular
          fontSize: 8 * scale,
          height: 1.0, // 칩 높이(18) 안에서 Row 가 세로 가운데 정렬
          letterSpacing: 0,
          color: AppColors.narText, // #FFFFFF
        ),
      ),
    );
  }

  /// 'vs' 라벨 — 빨강(#F03E3E) 텍스트, 배경 없음.
  Widget _vsLabel() {
    return Text(
      'VS',
      style: TextStyle(
        fontFamily: 'SF Pro',
        fontWeight: FontWeight.w400,
        fontSize: 8 * scale,
        height: 1.0,
        letterSpacing: 0,
        color: AppColors.narTextScore, // #F03E3E — vs 텍스트 색
      ),
    );
  }
}
