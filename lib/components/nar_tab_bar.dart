import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 가로 탭 바. 각 탭은 컨테이너(좌우 27.5 padding) 안에서 Expanded 로 균등 분배.
/// 시안 폭 376 기준 한 탭 107 인데, 프로젝트 베이스(375)와 1px 차이로 overflow 가 나
/// 마지막 탭("선수 평점")이 잘리는 걸 방지하기 위해 Expanded 로 자동 맞춤.
///
/// 선택 탭은 Pretendard w700 + narTextTertiary + 탭 폭 narBg 그라데이션 stroke,
/// 비선택은 w500 + narText3.
/// 활성 stroke 는 탭 박스 맨 아래에 위치하여 하단 보더 라인과 맞붙는다.
class NarTabBar extends StatelessWidget {
  const NarTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.scale = 1,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 27.5 * scale),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.narLine2, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: SizedBox(
                height: 45 * scale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            tabs[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 16 * scale,
                              height: 25 / 16,
                              color: i == selectedIndex
                                  ? AppColors.narTextTertiary
                                  : AppColors.narText3,
                            ),
                          ),
                        ),
                      ),
                      // 활성 stroke (탭 폭 전체). 비선택 탭은 같은 자리에 투명 컨테이너로
                      // 두어 선택/비선택 간 텍스트 위치가 흔들리지 않도록 한다.
                      Container(
                        height: 2 * scale,
                        decoration: i == selectedIndex
                            ? const BoxDecoration(gradient: AppColors.narBg)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
