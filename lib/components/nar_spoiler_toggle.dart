import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../styles/app_colors.dart';
import 'nar_toggle.dart';

/// 경기 카드 스코어 블러(스포방지) on/off 토글. 경기리스트·경기 상세(날짜별) 헤더에서 쓴다.
///
/// 시안 기준 라벨('스포방지 ON/OFF', SF Pro 400/14) + [NarToggle](34×19). 오른쪽 정렬.
/// 세로 패딩은 두지 않으므로 필요하면 호출부에서 감싼다.
/// 라벨 색·간격은 화면마다 시안이 달라 [textColor]·[gap] 으로 받는다
/// (경기리스트: narTextTertiary/gap 12, 경기 일정: narText/gap 4).
class NarSpoilerToggle extends StatelessWidget {
  const NarSpoilerToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.scale = 1,
    this.textColor = AppColors.narTextTertiary,
    this.gap = 12,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;
  final Color textColor;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            value ? l.spoilerPreventionOn : l.spoilerPreventionOff,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1.55,
              color: textColor,
            ),
          ),
          SizedBox(width: gap * scale),
          NarToggle(value: value, onChanged: onChanged, scale: scale),
        ],
      ),
    );
  }
}
