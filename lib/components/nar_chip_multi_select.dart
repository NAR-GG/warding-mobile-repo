import 'package:flutter/material.dart';

import 'nar_chip.dart';

/// 부모의 전체 너비를 차지하는 가로 스크롤 멀티 셀렉트 폼.
/// 컨테이너 패딩(가로 16, 세로 10) 안에 [NarChip] 을 8px 간격으로 늘어놓는다.
///
/// '전체' 같은 옵션이 필요하면 [options] 의 첫 항목으로 넣고
/// 호출부에서 선택 상태를 처리한다 (예: 전체 선택 시 나머지 비우기).
class NarChipMultiSelect extends StatelessWidget {
  const NarChipMultiSelect({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.scale = 1,
  });

  final List<String> options;
  final Set<String> selectedValues;
  final ValueChanged<Set<String>> onChanged;
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

  @override
  Widget build(BuildContext context) {
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
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) SizedBox(width: 8 * scale),
              NarChip(
                label: options[i],
                selected: selectedValues.contains(options[i]),
                onTap: () => _toggle(options[i]),
                scale: scale,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
