import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../styles/app_colors.dart';

/// "5승 2패" — 승은 빨강([AppColors.scoreWin]), 패는 기본색.
///
/// 앱 곳곳에서 같은 문구를 저마다 다르게 칠하던 것을 하나로 모은 것이다.
/// 문구 자체는 로케일 문자열(`playerWinLoss`)을 쓰고, 승 부분만 색을 입힌다.
/// 0판이면 [emptyPlaceholder] 를 그린다(기본 "—").
class WinLossText extends StatelessWidget {
  const WinLossText({
    super.key,
    required this.wins,
    required this.losses,
    required this.style,
    this.emptyPlaceholder = '—',
    this.emptyStyle,
  });

  final int wins;
  final int losses;

  /// 전체 문구의 기본 스타일. 승 부분만 이 위에 승리 색을 덧씌운다.
  final TextStyle style;

  /// 0판일 때 보일 문자열.
  final String emptyPlaceholder;

  /// 0판일 때 스타일. null 이면 [style] 그대로.
  final TextStyle? emptyStyle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (wins + losses == 0) {
      return Text(emptyPlaceholder, style: emptyStyle ?? style);
    }
    // 로케일 문구에서 승·패를 가르는 기준은 첫 공백이다("5승 2패" / "5W 2L").
    final text = l.playerWinLoss(wins, losses);
    final split = text.indexOf(' ');
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: split < 0 ? text : text.substring(0, split),
            style: const TextStyle(color: AppColors.scoreWin),
          ),
          if (split >= 0) TextSpan(text: text.substring(split)),
        ],
      ),
      style: style,
    );
  }
}
