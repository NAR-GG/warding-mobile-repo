import 'package:flutter/material.dart';

import '../../../components/nar_chip.dart';
import '../../../components/nar_filter_sheet.dart';
import '../../../styles/app_colors.dart';

/// 선수 선택 바텀시트.
///
/// 공용 [NarFilterSheet] 위에 '구독한 선수' 칩 목록을 얹는다.
/// 선택된 선수는 [NarChip.filter](보라 + circle-x), 미선택은 기본 토글 칩으로
/// 그린다. 조회 버튼은 한 명 이상 선택됐을 때 활성된다.
/// [showAppBottomSheet] 의 child 로 띄우고, 조회 시 선택한 선수 집합을 반환한다.
class PlayerSelectSheet extends StatefulWidget {
  const PlayerSelectSheet({
    super.key,
    required this.players,
    this.initialSelected = const {},
  });

  /// 구독한 선수 목록.
  final List<String> players;

  /// 초기 선택 상태.
  final Set<String> initialSelected;

  @override
  State<PlayerSelectSheet> createState() => _PlayerSelectSheetState();
}

class _PlayerSelectSheetState extends State<PlayerSelectSheet> {
  late final Set<String> _selected = Set<String>.from(widget.initialSelected);

  void _toggle(String player) {
    setState(() {
      if (_selected.contains(player)) {
        _selected.remove(player);
      } else {
        _selected.add(player);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return NarFilterSheet(
      title: '선수 선택',
      onReset: () => setState(_selected.clear),
      // 선수를 안 골라도 조회 가능 (빈 선택이면 선수 필터 해제로 동작).
      onApply: () => Navigator.of(context).pop(_selected),
      // 칩 영역 — 좌우 20 들여쓰기.
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '구독한 선수',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 16 * scale,
                height: 1,
                color: AppColors.narText,
              ),
            ),
            SizedBox(height: 8 * scale), // 라벨 ↔ 칩 간격 8
            Wrap(
              spacing: 8 * scale, // 칩 가로 간격 8
              runSpacing: 8 * scale, // 칩 세로 간격 8
              children: [
                for (final player in widget.players)
                  _selected.contains(player)
                      ? NarChip.filter(
                          label: player,
                          scale: scale,
                          onTap: () => _toggle(player),
                        )
                      : NarChip(
                          label: player,
                          selected: false,
                          scale: scale,
                          onTap: () => _toggle(player),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
