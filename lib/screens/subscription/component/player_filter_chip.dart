import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_chip.dart';

/// 마이 구독 선수 필터 칩. 선택 상태에 따라 모양이 달라진다.
///
/// - 0명: 기본 '선수전체' 드롭다운 칩 (회색 테두리).
/// - 1 ~ (전체-1)명: 활성 칩 — 첫 선수명 + 선택 수 배지 + chevron.
/// - 전체: 활성 칩 — '선수' + '전체' 배지 + circle-x(탭 시 초기화).
///
/// 본문 탭은 [onTap] (보통 선수 선택 바텀시트 열기), 전체 선택 칩의 circle-x 탭은
/// [onClear] (선택 초기화) 로 간다.
class PlayerFilterChip extends StatelessWidget {
  const PlayerFilterChip({
    super.key,
    required this.players,
    required this.selected,
    required this.scale,
    this.onTap,
    this.onClear,
  });

  /// 전체 선수 목록.
  final List<String> players;

  /// 선택된 선수 집합.
  final Set<String> selected;

  final double scale;

  /// 칩 본문 탭 콜백 (보통 선수 선택 바텀시트 열기).
  final VoidCallback? onTap;

  /// 전체 선택 칩의 circle-x 탭 콜백 (선택값 초기화).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 0명 — 기본 드롭다운 칩.
    if (selected.isEmpty) {
      return NarChip.dropdown(label: l.allPlayers, scale: scale, onTap: onTap);
    }

    // 전체 선택 — '선수' + '전체' 배지 + circle-x.
    if (players.isNotEmpty && selected.length >= players.length) {
      return NarChip.active(
        label: l.player,
        badge: l.all,
        trailing: NarChipTrailing.remove,
        scale: scale,
        onTap: onTap,
        onRemove: onClear,
      );
    }

    // 일부 선택 — 첫 선수명 + 선택 수 배지 + chevron.
    // players 순서 기준 첫 선택 선수를 대표로 보여준다.
    final first = players.firstWhere(
      selected.contains,
      orElse: () => selected.first,
    );
    return NarChip.active(
      label: first,
      badge: '${selected.length}',
      scale: scale,
      onTap: onTap,
    );
  }
}
