import 'package:flutter/material.dart';

import 'nar_chip.dart';

/// 부모의 전체 너비를 차지하는 가로 스크롤 멀티 셀렉트 폼.
/// 컨테이너 패딩(가로 [horizontalPadding], 세로 10) 안에 [NarChip] 을 8px
/// 간격으로 늘어놓는다.
///
/// 기본은 선택된 칩을 앞으로 정렬한다(원래 상대 순서 유지). 정렬에서 빼고 맨
/// 앞에 고정할 옵션은 [pinned] 에 넣는다 (예: '전체'). [reorderSelected] 를
/// false 로 두면 선택해도 순서를 바꾸지 않는다(이때 [pinned] 는 의미가 없고
/// 옵션은 준 순서 그대로, [trailing] 은 그 뒤에 준 순서대로 붙는다).
///
/// [trailing] 에는 토글 옵션이 아닌 별도 칩(예: 선수 선택 칩)을 넣는다.
/// 각 항목의 `selected` 가 true 면 선택된 옵션들과 함께 앞쪽으로,
/// false 면 맨 뒤로 정렬된다.
///
/// [disabledOptions] 에 든 옵션은 [NarChip.disabled] 점선 칩으로 그리며
/// 선택할 수 없고 선택 정렬에도 끼지 않는다.
///
/// 탭처럼 하나만 고르는 용도는 [NarChipMultiSelect.single] 을 쓴다.
class NarChipMultiSelect extends StatelessWidget {
  const NarChipMultiSelect({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.labelBuilder,
    this.pinned = const {},
    this.trailing = const [],
    this.reorderSelected = true,
    this.disabledOptions = const {},
    this.horizontalPadding = 16,
    this.scale = 1,
  }) : _onPick = null;

  /// 단일 선택 탭 줄. 선택해도 칩 순서가 바뀌지 않고, 이미 선택된 칩을 다시
  /// 눌러도 아무 일도 없다(해제 없음). [disabledOptions] 칩은 탭을 받지 않는다.
  /// 새 값을 고를 때만 [onSelected] 가 한 번 불린다.
  NarChipMultiSelect.single({
    super.key,
    required this.options,
    required String selected,
    required ValueChanged<String> onSelected,
    this.labelBuilder,
    this.disabledOptions = const {},
    this.horizontalPadding = 16,
    this.scale = 1,
  }) : selectedValues = {selected},
       onChanged = _ignore,
       pinned = const {},
       trailing = const [],
       reorderSelected = false,
       _onPick = onSelected;

  static void _ignore(Set<String> _) {}

  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;

  /// 내부 키 값을 표시 라벨로 변환하는 함수. null 이면 값 자체를 라벨로 쓴다.
  final String Function(String value)? labelBuilder;

  /// 정렬에서 제외하고 항상 맨 앞에 원래 순서로 고정할 옵션들.
  final Set<String> pinned;

  /// 토글 옵션이 아닌 별도 칩. `selected` 여부로 앞/뒤 정렬에 참여한다.
  final List<({Widget widget, bool selected})> trailing;

  /// false 면 선택해도 옵션 순서를 바꾸지 않는다.
  final bool reorderSelected;

  /// 점선 비활성 칩으로 그릴 옵션들. 선택되지 않는다.
  final Set<String> disabledOptions;

  /// 스크롤 영역 좌우 패딩(기본 16). 섹션 헤더와 칩 줄을 맞출 때 조절한다.
  final double horizontalPadding;
  final double scale;

  /// [NarChipMultiSelect.single] 의 선택 콜백. null 이면 멀티 셀렉트.
  final ValueChanged<String>? _onPick;

  void _toggle(String value) {
    final pick = _onPick;
    if (pick != null) {
      if (!selectedValues.contains(value)) pick(value);
      return;
    }
    final next = Set<String>.from(selectedValues);
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    onChanged(next);
  }

  Widget _chip(String value) {
    final label = labelBuilder != null ? labelBuilder!(value) : value;
    if (disabledOptions.contains(value)) {
      return NarChip.disabled(label: label, scale: scale);
    }
    return NarChip(
      label: label,
      selected: selectedValues.contains(value),
      onTap: () => _toggle(value),
      scale: scale,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 정렬: 고정 옵션 → 선택된 나머지 옵션 → 선택된 trailing
    //       → 미선택 옵션 → 미선택 trailing. (각 그룹 내 원래 순서 유지)
    bool isSelected(String o) =>
        selectedValues.contains(o) && !disabledOptions.contains(o);
    final rest = options.where((o) => !pinned.contains(o));
    final items = reorderSelected
        ? <Widget>[
            for (final o in options.where(pinned.contains)) _chip(o),
            for (final o in rest.where(isSelected)) _chip(o),
            for (final t in trailing.where((t) => t.selected)) t.widget,
            for (final o in rest.where((o) => !isSelected(o))) _chip(o),
            for (final t in trailing.where((t) => !t.selected)) t.widget,
          ]
        : <Widget>[
            for (final o in options) _chip(o),
            for (final t in trailing) t.widget,
          ];

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding * scale,
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
