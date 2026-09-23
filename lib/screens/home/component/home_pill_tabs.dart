import 'package:flutter/material.dart';

import '../../../components/dashed_border.dart';
import '../../../styles/app_colors.dart';

/// [HomePillTabs] 의 칩 하나.
class HomePillTab<T> {
  const HomePillTab({
    required this.value,
    required this.label,
    this.enabled = true,
    this.key,
  });

  final T value;
  final String label;

  /// false 면 점선 칩으로 그리고 탭을 받지 않는다(데이터가 아직 없는 리그 등).
  final bool enabled;
  final Key? key;
}

/// 홈 섹션의 한 줄 칩 탭(순위표 리그, 커뮤니티 정렬, 콘텐츠 탭, 쇼츠 필터).
///
/// 공용 [NarChipMultiSelect] 는 고른 칩을 맨 앞으로 옮기는데, 홈의 칩은 탭이라
/// 누를 때마다 순서가 바뀌면 안 된다. 그래서 순서를 고정한 단일 선택 칩 줄을
/// 따로 둔다. 모양은 목업의 `.lc`/`.ctabs` — 높이 30, 선택 칩은 선택 칩 공용
/// 관례(narChipSelectedBg 배경 + narChipActive 테두리)를 따른다.
class HomePillTabs<T> extends StatelessWidget {
  const HomePillTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    required this.scale,
  });

  final List<HomePillTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(20 * scale, 0, 20 * scale, 10 * scale),
      child: Row(
        children: [
          for (final (i, tab) in tabs.indexed) ...[
            if (i > 0) SizedBox(width: 6 * scale),
            _chip(tab),
          ],
        ],
      ),
    );
  }

  Widget _chip(HomePillTab<T> tab) {
    final isSelected = tab.enabled && tab.value == selected;
    final label = Text(
      tab.label,
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w600,
        fontSize: 12.5 * scale,
        height: 1,
        color: !tab.enabled
            ? AppColors.narDark200
            : isSelected
            ? AppColors.narText
            : AppColors.narText3,
      ),
    );
    final radius = 15 * scale;

    if (!tab.enabled) {
      // 누를 수 없는 칩 — 점선만 두르고 GestureDetector 를 달지 않는다.
      return KeyedSubtree(
        key: tab.key,
        child: DashedBorder(
          radius: radius,
          child: Container(
            height: 30 * scale,
            padding: EdgeInsets.symmetric(horizontal: 12 * scale),
            alignment: Alignment.center,
            child: label,
          ),
        ),
      );
    }

    return GestureDetector(
      key: tab.key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isSelected) onSelected(tab.value);
      },
      child: Container(
        height: 30 * scale,
        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.narChipSelectedBg : null,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isSelected ? AppColors.narChipActive : AppColors.narLine2,
          ),
        ),
        child: label,
      ),
    );
  }
}
