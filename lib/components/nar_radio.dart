import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 앱 공용 라디오 버튼 (기준 20×20) + 우측 라벨.
///
/// 디자인 스펙:
/// - 선택: 바깥 원을 [AppColors.narBg] 그라데이션으로 채우고, 가운데 8 짜리
///   구멍(카드 배경색 [dotColor])을 뚫어 도넛처럼 보이게 한다.
/// - 미선택: 1px [AppColors.narDark300] 테두리만.
/// - 라디오↔라벨 간격 8, 라벨은 14/400 [AppColors.narTextTertiary].
///
/// [selected] 로 상태를 받고 [onTap] 으로 선택을 통지한다(제어 컴포넌트).
/// [onTap] 이 null 이면 비활성(탭 무시).
class NarRadio extends StatelessWidget {
  const NarRadio({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.scale = 1,
    this.dotColor = AppColors.narBgTertiary,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double scale;

  /// 선택 상태에서 가운데 구멍에 칠할 색. 라디오가 놓인 배경색과 맞춘다.
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final size = 20 * scale;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: selected
                ? DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppColors.narBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      // 가운데 8 구멍 — 배경색과 같은 색으로 덮어 도넛을 만든다.
                      child: Container(
                        width: 8 * scale,
                        height: 8 * scale,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.narDark300,
                        width: 1 * scale,
                      ),
                    ),
                  ),
          ),
          SizedBox(width: 8 * scale),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1.55,
              color: AppColors.narTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
