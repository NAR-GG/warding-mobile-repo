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
    this.compactHorizontalPadding = 20,
    this.leadingIcons,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final NarTabBarVariant variant;
  final double scale;

  /// 탭 라벨 앞에 붙일 아이콘. [tabs] 와 같은 길이여야 하며, 항목이 null 이면
  /// 그 탭은 아이콘 없이 라벨만 그린다. 지정하지 않으면(null) 전부 라벨만
  /// 그린다(기존 동작 그대로). [NarTabBarVariant.page] 에서만 쓴다.
  final List<Widget?>? leadingIcons;

  /// [NarTabBarVariant.compact] 의 좌우 패딩(기본 20).
  /// 카드 안에서 쓸 때처럼 더 좁게 붙여야 하면 낮춘다(예: 8).
  final double compactHorizontalPadding;

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
        border: Border(bottom: BorderSide(color: AppColors.narLine2, width: 1)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: SizedBox(
                height: 45 * scale,
                // 탭 한 칸의 실제 폭을 재서 아래 ConstrainedBox 에 넘긴다 —
                // "라이브 이벤트"처럼 긴 라벨은 IntrinsicWidth 가 이 폭을 넘는
                // 크기로 렌더돼 Row 가 overflow 했다(실기기 폭 375~430에서만
                // 재현, 테스트 기본 캔버스(800)는 안 걸림). 폭을 씌우면
                // Text 의 기존 ellipsis 가 정상적으로 안전망 역할을 한다.
                child: LayoutBuilder(
                  builder: (context, tabConstraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    // stroke 는 라벨 텍스트 폭에만 맞춘다(아이콘 제외) — 아이콘까지
                    // 포함해서 재면 아이콘 있는 탭만 stroke 가 더 넓어져, 색이 같은
                    // narBg 그라데이션이라도 아이콘 없는 탭(경기상세 탭 등)보다
                    // 굵고 진하게 보인다.
                    //
                    // 텍스트(+stroke) 블록을 정중앙에 두려고 아이콘 폭만큼 반대편에
                    // 투명 자리를 맞춰 두는 방식은 아이콘의 실측 폭이 100% 안 맞으면
                    // 살짝 밀린다. 대신 양옆에 동일 flex(1)인 Expanded 를 하나씩 둬서
                    // — 폭을 재지 않아도 항상 정확히 반반 나뉘도록 — 가운데 텍스트
                    // 블록을 수학적으로 정확히 중앙에 놓는다. 아이콘은 왼쪽 Expanded
                    // 안에서 오른쪽 정렬해 텍스트 바로 옆에 붙인다.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: leadingIcons?[i] == null
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 4 * scale),
                                    child: leadingIcons![i],
                                  ),
                                ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: tabConstraints.maxWidth,
                          ),
                          child: IntrinsicWidth(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Center(
                                    // 좌우로 여백을 줘서 stroke 가 텍스트보다 살짝 더
                                    // 넓게(아래) 깔리게 한다. stroke 는 이 Padding 을
                                    // 포함한 열 전체 폭에 맞춰 stretch 되기 때문에,
                                    // 텍스트 자체의 폭이 아니라 이 여백이 stroke 폭을
                                    // 정한다.
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6 * scale,
                                      ),
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
                                ),
                                // 활성 stroke. 비선택 탭은 같은 자리에 투명 컨테이너로
                                // 두어 선택/비선택 간 텍스트 위치가 흔들리지 않도록 한다.
                                Container(
                                  height: 2 * scale,
                                  decoration: i == selectedIndex
                                      ? const BoxDecoration(
                                          gradient: AppColors.narBg,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 콤팩트 탭. 컨테이너 좌패딩 [compactHorizontalPadding], 탭 간 gap 4, 탭마다 패딩 3/12.
  /// 선택 탭은 w700 + 하단 narBg 그라데이션 stroke, 비선택은 w500 — narTextTertiary 단일 색.
  Widget _buildCompact() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compactHorizontalPadding * scale,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: 4 * scale),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              // IntrinsicWidth 로 하단 stroke 가 텍스트(+ 좌우 패딩 12) 폭에 딱 맞게
              // 늘어나도록. stroke 는 Stack 으로 텍스트 블록 바깥에 겹쳐 그려 레이아웃
              // 높이에 포함시키지 않는다 — Column 으로 쌓으면 이 위젯 전체를 다른 곳에서
              // 세로 중앙 정렬할 때 stroke 자리(2*scale)만큼 텍스트가 중심보다 위로 밀린다.
              child: IntrinsicWidth(
                child: Stack(
                  clipBehavior: Clip.none,
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
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -2 * scale,
                      child: Container(
                        height: 2 * scale,
                        decoration: i == selectedIndex
                            ? const BoxDecoration(gradient: AppColors.narBg)
                            : null,
                      ),
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
