import 'package:flutter/material.dart';

import 'nar_chip.dart';

/// 부모의 전체 너비를 차지하는 가로 스크롤 멀티 셀렉트 폼.
/// 컨테이너 패딩(가로 16, 세로 10) 안에 [NarChip] 을 8px 간격으로 늘어놓는다.
///
/// 선택된 칩은 앞으로 정렬된다(원래 상대 순서 유지). 정렬에서 빼고 맨 앞에
/// 고정할 옵션은 [pinned] 에 넣는다 (예: '전체').
///
/// [trailing] 에는 토글 옵션이 아닌 별도 칩(예: 선수 선택 칩)을 넣는다.
/// 각 항목의 `selected` 가 true 면 선택된 옵션들과 함께 앞쪽으로,
/// false 면 맨 뒤로 정렬된다.
class NarChipMultiSelect extends StatelessWidget {
  const NarChipMultiSelect({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.pinned = const {},
    this.trailing = const [],
    this.scale = 1,
  });

  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;

  /// 정렬에서 제외하고 항상 맨 앞에 원래 순서로 고정할 옵션들.
  final Set<String> pinned;

  /// 토글 옵션이 아닌 별도 칩. `selected` 여부로 앞/뒤 정렬에 참여한다.
  final List<({Widget widget, bool selected})> trailing;
  final double scale;

  void _toggle(String value) {
    final next = Set<String>.from(selectedValues);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    onChanged(next);
  }

  NarChip _chip(String value) => NarChip(
    label: value,
    selected: selectedValues.contains(value),
    onTap: () => _toggle(value),
    scale: scale,
  );

  @override
  Widget build(BuildContext context) {
    // 정렬: 고정 옵션 → 선택된 나머지 옵션 → 선택된 trailing
    //       → 미선택 옵션 → 미선택 trailing. (각 그룹 내 원래 순서 유지)
    final rest = options.where((o) => !pinned.contains(o));
    final items = <Widget>[
      for (final o in options.where(pinned.contains)) _chip(o),
      for (final o in rest.where(selectedValues.contains)) _chip(o),
      for (final t in trailing.where((t) => t.selected)) t.widget,
      for (final o in rest.where((o) => !selectedValues.contains(o))) _chip(o),
      for (final t in trailing.where((t) => !t.selected)) t.widget,
    ];

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 10 * scale,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: 8 * scale),
              items[i],
            ],
          ],
        ),
      ),
    );
  }
}
