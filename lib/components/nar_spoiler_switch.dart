import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 스포방지 전용 ON/OFF 토글 스위치 (경기리스트·경기 일정 헤더).
///
/// 알림·마이페이지 등에서 쓰는 [NarToggle] 과 시안이 달라 별도 컴포넌트로 둔다.
///
/// 디자인 스펙(기준 34×19, padding 2, 노브 15×15, radius 완전 둥글게):
/// - OFF : 트랙 [AppColors.narText2](#A6A7AB), 노브 [AppColors.narSpoilerKnobOff]
///         (rgba(20,21,23,0.4)) 가 좌측.
/// - ON  : 트랙 [AppColors.narTextTertiary](#FCFDFE), 노브
///         [AppColors.narDark800](#141517) 가 우측.
/// - 트랙 inset 그림자 `inset 0 2px 4px rgba(0,0,0,0.14)`. Flutter 는 inset
///   그림자를 지원하지 않으므로 트랙 상단을 덮는 세로 그라데이션으로 근사한다.
///
/// [value] 로 상태를 받고 [onChanged] 로 변경을 통지한다(제어 컴포넌트).
/// [onChanged] 가 null 이면 비활성(탭 무시).
class NarSpoilerSwitch extends StatelessWidget {
  const NarSpoilerSwitch({
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
    final radius = BorderRadius.circular(trackHeight / 2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: trackWidth,
        height: trackHeight,
        decoration: BoxDecoration(
          color: value ? AppColors.narTextTertiary : AppColors.narText2,
          borderRadius: radius,
        ),
        child: Stack(
          children: [
            // inset 0 2px 4px rgba(0,0,0,0.14) 근사 — 상단이 진하고 아래로 사라진다.
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.narSpoilerTrackShadow,
                        Color(0x00000000),
                      ],
                      stops: [0.0, 0.45],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(2 * scale),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                alignment: value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    color: value
                        ? AppColors.narDark800
                        : AppColors.narSpoilerKnobOff,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
