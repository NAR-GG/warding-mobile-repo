import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../styles/app_colors.dart';
import 'nar_spoiler_switch.dart';

/// 경기 카드 스코어 블러(스포방지) on/off 토글. 경기리스트·경기 상세(날짜별) 헤더에서 쓴다.
///
/// 시안 컨테이너(123×38, padding 8px 0, gap 12, 우측 정렬):
/// 라벨('스포방지 ON/OFF', SF Pro 400/14, line-height 155%, #FCFDFE) +
/// [NarSpoilerSwitch](34×19). 폭 123 = 라벨 77 + gap 12 + 토글 34.
/// 두 화면 시안이 같아 기본값을 그대로 쓰면 되고,
/// 라벨 색·간격만 다른 시안이 생기면 [textColor]·[gap] 으로 덮는다.
class NarSpoilerToggle extends StatelessWidget {
  const NarSpoilerToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.scale = 1,
    this.textColor = AppColors.narTextTertiary,
    this.gap = 12,
    this.verticalPadding = 8,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;
  final Color textColor;
  final double gap;

  /// 시안 컨테이너의 상하 패딩(기본 8 → 높이 38).
  /// 높이가 고정된 슬롯에 넣을 때는 0 으로 줄여 세로 오버플로를 막는다
  /// (예: [NarDetailHeader] 는 높이 34 라 38 이 들어가면 넘친다).
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        // 시안 컨테이너: padding 8px 0 → 라벨 22 + 상하 8 = 높이 38.
        padding: EdgeInsets.symmetric(vertical: verticalPadding * scale),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 라벨 길이는 상태·언어마다 다르다('스포방지 OFF', 'Spoiler OFF' 등).
            // 좁은 폭에서 토글까지 밀어내 오버플로가 나지 않게 라벨만 줄인다.
            Flexible(
              child: Text(
                value ? l.spoilerPreventionOn : l.spoilerPreventionOff,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w400,
                  fontSize: 14 * scale,
                  height: 1.55,
                  color: textColor,
                ),
              ),
            ),
            SizedBox(width: gap * scale),
            NarSpoilerSwitch(value: value, onChanged: onChanged, scale: scale),
          ],
        ),
      ),
    );
  }
}
