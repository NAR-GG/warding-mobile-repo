import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import 'calendar_match.dart';

/// 경기 칩 — 50×15, 라운드 8, 1px 테두리. 안에 [홈팀] vs [원정팀].
///
/// 시안은 18 이었는데, 캘린더가 아래 경기 리스트와 세로를 나눠 쓰게 되면서
/// 한 칸에 칩이 하나밖에 안 들어갔다. 글자(8)는 그대로 두고 위아래 여백만
/// 줄여 같은 칸에 두 개가 들어가게 했다.
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
      height: 15 * scale,
      // 좌우 같은 여백. 1 이면 팀 코드가 테두리에 닿아 한쪽으로 쏠려 보이고,
      // 크게 주면 네 글자 코드(TLAW·LYON)가 [FittedBox] 로 많이 줄어든다.
      padding: EdgeInsets.symmetric(horizontal: 2 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgTertiary, // #1F2024
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: AppColors.narLine, width: 1), // #343A40
      ),
      // 양쪽 팀 이름 칸을 같은 폭(flex 1)으로 나누고, 각 칸 안에서 가운데
      // 정렬한다. 기본 정렬로 두면 두 글자(KT)와 네 글자(TLAW)가 섞일 때
      // 한쪽은 테두리에 붙고 반대쪽은 vs 에서 멀어져 비뚤어 보인다.
      child: Row(
        children: [
          Expanded(child: Center(child: _teamName(match.home))),
          _vsLabel(),
          Expanded(child: Center(child: _teamName(match.away))),
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
  ///
  /// 좌우에 같은 간격을 둬 팀 이름과 붙지 않게 한다. 간격이 없으면
  /// 'TLAWVSLYON' 처럼 한 덩어리로 읽힌다.
  Widget _vsLabel() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1 * scale),
      child: Text(
        'VS',
        style: TextStyle(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w400,
          fontSize: 8 * scale,
          height: 1.0,
          letterSpacing: 0,
          color: AppColors.narTextScore, // #F03E3E — vs 텍스트 색
        ),
      ),
    );
  }
}
