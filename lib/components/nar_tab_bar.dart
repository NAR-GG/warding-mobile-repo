import 'package:flutter/material.dart';

import '../styles/app_colors.dart';

/// 탭 바 변형.
enum NarTabBarVariant {
  /// 페이지 상단 탭. 균등 폭, 45 높이, 하단 보더 + 활성 그라데이션 stroke.
  page,

  /// 섹션 내부 좌측 정렬 콤팩트 탭. 31 높이, 콘텐츠 폭, 좌패딩 20, 탭 간 gap 4.
  /// 하단 보더·활성 stroke 없이 폰트 굵기로만 선택 상태 구분.
  compact,
}

/// 가로 탭 바.
///
/// - [page]: 시안 폭 376 기준 한 탭 107 인데 프로젝트 베이스(375)와 1px 차이로 overflow 가
///   나 마지막 탭이 잘리는 걸 방지하기 위해 Expanded 로 자동 맞춤. 선택 탭은 Pretendard w700
///   + narTextTertiary + 탭 폭 narBg 그라데이션 stroke, 비선택은 w500 + narText3.
/// - [compact]: 전체 목록 같은 섹션 내부에서 좌측 정렬로 쓰는 콤팩트 탭.
class NarTabBar extends StatelessWidget {
  const NarTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.variant = NarTabBarVariant.page,
    this.scale = 1,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final NarTabBarVariant variant;
  final double scale;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case NarTabBarVariant.page:
        return _buildPage();
      case NarTabBarVariant.compact:
        return _buildCompact();
    }
  }

  Widget _buildPage() {
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
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
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

  /// 콤팩트 탭. 컨테이너 좌패딩 20, 탭 간 gap 4, 탭마다 패딩 3/12.
  /// 선택 탭은 w700 + 하단 narBg 그라데이션 stroke, 비선택은 w500 — narTextTertiary 단일 색.
  Widget _buildCompact() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: 4 * scale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              // IntrinsicWidth + crossAxisAlignment.stretch 로 하단 stroke 가
              // 텍스트(+ 좌우 패딩 12) 폭에 딱 맞게 늘어나도록.
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 3 * scale,
                        horizontal: 12 * scale,
                      ),
                      child: Text(
                        tabs[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: i == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 16 * scale,
                          height: 1.55, // 155%
                          color: AppColors.narTextTertiary,
                        ),
                      ),
                    ),
                    // 활성 stroke. 비선택 탭도 같은 자리에 투명 컨테이너로 둬
                    // 선택/비선택 간 텍스트 위치가 흔들리지 않도록 한다.
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
          ],
        ],
      ),
    );
  }
}
