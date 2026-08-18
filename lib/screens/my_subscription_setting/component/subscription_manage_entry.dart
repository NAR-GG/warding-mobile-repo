import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/app_localizations.dart';
import '../../../styles/app_colors.dart';

/// 마이 구독 설정 화면 상단의 '구독 관리' 진입 카드 (양옆 20 패딩).
///
/// 상단: '구독 관리' 라벨(15/600 회색).
/// 하단: narBgTertiary 카드 안에 '팀/ 선수 구독 관리' + chevron,
/// 그 아래 안내 문구. 카드를 탭하면 [onTap] (구독 설정 페이지 이동).
class SubscriptionManageEntry extends StatelessWidget {
  const SubscriptionManageEntry({super.key, this.scale = 1, this.onTap});

  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 섹션 라벨 (padding 10/0 → 높이 45).
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10 * scale),
            child: Text(
              l.subscriptionManage,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 15 * scale,
                height: 25 / 15,
                color: AppColors.narText4,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.fromLTRB(12 * scale, 0, 0, 8 * scale),
              decoration: BoxDecoration(
                color: AppColors.narBgTertiary,
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 타이틀 + chevron (높이 44).
                  SizedBox(
                    height: 44 * scale,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          l.teamPlayerSubscriptionManage,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: 17 * scale,
                            height: 25 / 17,
                            color: AppColors.narText,
                          ),
                        ),
                        SizedBox(
                          width: 44 * scale,
                          height: 44 * scale,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/chevron-right.svg',
                              width: 24 * scale,
                              height: 24 * scale,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 안내 문구 (높이 25).
                  Text(
                    l.subscriptionManageDescription,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      fontSize: 14 * scale,
                      height: 25 / 14,
                      color: AppColors.narText4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
