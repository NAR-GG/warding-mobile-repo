import 'package:flutter/material.dart';

import '../../../components/nar_button.dart';
import '../../../styles/app_colors.dart';

/// 구독한 선수 평점 유도 배너.
///
/// '회원님이 구독한 선수'(narBg 그라데이션) 안내 + '{팀} {선수}님에게 평점를
/// 남겨보세요!' 문구 + 우측 '평점 남기기' 버튼(공용 [NarButton] set1)으로 구성된다.
/// 구독한 선수의 평점 상세에서 아직 평점을 남기지 않았을 때 노출한다.
class SubscribedRatingBanner extends StatelessWidget {
  const SubscribedRatingBanner({
    super.key,
    required this.teamName,
    required this.playerName,
    this.onRate,
    this.scale = 1,
  });

  /// 선수 소속 팀 이름(예: 'T1').
  final String teamName;

  /// 선수 이름(예: 'Faker').
  final String playerName;

  /// '평점 남기기' 탭 콜백. null 이면 버튼이 비활성된다(평점 불가 세트 등).
  final VoidCallback? onRate;

  final double scale;

  @override
  Widget build(BuildContext context) {
    // player.name 이 이미 '팀 선수'(예: 'T1 Peyz') 형태면 팀명을 덧붙이지 않는다
    // (안 그러면 'T1 T1 Peyz' 처럼 팀명이 중복된다).
    final displayName =
        (teamName.isEmpty || playerName.startsWith('$teamName '))
            ? playerName
            : '$teamName $playerName';
    return Container(
      width: double.infinity,
      color: AppColors.narBgContent, // #101113
      padding:
          EdgeInsets.symmetric(vertical: 10 * scale, horizontal: 20 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // '회원님이 구독한 선수' — narBg 그라데이션 텍스트.
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.narBg.createShader(bounds),
                  child: Text(
                    '회원님이 구독한 선수',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      fontSize: 11 * scale,
                      height: 1.45,
                      // ShaderMask 가 덮어쓰므로 흰색이어야 그라데이션이 보인다.
                      color: AppColors.narText,
                    ),
                  ),
                ),
                // '{팀} {선수}'(굵게) + '님에게 평점를 남겨보세요!'(보통).
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '님에게 평점를 남겨보세요!'),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                    fontSize: 14 * scale,
                    height: 1.55,
                    color: AppColors.narText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * scale),
          // 우측 '평점 남기기' 버튼 — 공용 NarButton set1(narDark300 #5C5F66).
          SizedBox(
            width: 90 * scale,
            child: NarButton(
              variant: NarButtonVariant.set1,
              label: '평점 남기기',
              onPressed: onRate,
              scale: scale,
            ),
          ),
        ],
      ),
    );
  }
}
