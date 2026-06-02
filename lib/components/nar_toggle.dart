import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 앱 공용 ON/OFF 토글 스위치.
///
/// 디자인 스펙(기준 34×19):
/// - ON  : 트랙 [AppColors.narBg] 그라데이션, 노브(흰색)가 우측.
/// - OFF : 트랙 [AppColors.narText2](#A6A7AB), 노브([AppColors.narDark600] #25262B)가 좌측.
/// - 트랙 padding 2, 노브 15×15, 완전 둥근 모서리.
///
/// [value] 로 상태를 받고 [onChanged] 로 변경을 통지한다(제어 컴포넌트).
/// [onChanged] 가 null 이면 비활성(탭 무시).
class NarToggle extends StatelessWidget {
  const NarToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.scale = 1,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final trackWidth = 34 * scale;
    final trackHeight = 19 * scale;
    final knobSize = 15 * scale;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: trackWidth,
        height: trackHeight,
        padding: EdgeInsets.all(2 * scale),
        decoration: BoxDecoration(
          // ON 은 그라데이션, OFF 는 단색.
          gradient: value ? AppColors.narBg : null,
          color: value ? null : AppColors.narText2,
          borderRadius: BorderRadius.circular(trackHeight / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knobSize,
            height: knobSize,
            decoration: BoxDecoration(
              // ON 노브 흰색, OFF 노브 #25262B.
              color: value ? AppColors.narText : AppColors.narDark600,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
