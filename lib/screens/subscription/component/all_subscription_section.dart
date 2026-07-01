import 'package:flutter/material.dart';

import '../../../components/nar_tab_bar.dart';
import '../../../styles/app_colors.dart';
import 'subscribed_section.dart';

/// 구독 설정 화면의 '전체 목록' 섹션.
///
/// 상단 narBgLast 헤더 바 + 8 gap + 콤팩트 탭바([팀]/[선수]) + 8 gap + 행 리스트.
/// 행은 [SubscribedItemRow] 를 재사용하며 짝수 index 행만 narBgSecondary 배경으로
/// 알록달록 띠를 입힌다.
///
/// 선택 탭은 부모가 제어한다([selectedTab]·[onTabChanged]). 검색 시 부모가
/// '선수' 탭으로 전환하고 이 섹션을 최상단으로 올리기 위함이다.
class AllSubscriptionSection extends StatelessWidget {
  const AllSubscriptionSection({
    super.key,
    required this.teams,
    required this.players,
    required this.selectedTab,
    required this.onTabChanged,
    this.onTeamToggle,
    this.onPlayerToggle,
    this.playersLoading = false,
    this.playersLoadingMore = false,
    this.scale = 1,
  });

  /// 전체 팀 목록 (구독 여부 포함).
  final List<SubscribedItem> teams;

  /// 전체 선수 목록 (구독 여부 포함).
  final List<SubscribedItem> players;

  /// 현재 선택된 탭. 0: 팀, 1: 선수.
  final int selectedTab;

  /// 탭 변경 콜백.
  final ValueChanged<int> onTabChanged;

  /// 팀 탭의 구독 토글 콜백.
  final void Function(int index)? onTeamToggle;

  /// 선수 탭의 구독 토글 콜백.
  final void Function(int index)? onPlayerToggle;

  /// 선수 목록 최초 로딩 중인지 (목록이 비어있는 동안 스피너 표시).
  final bool playersLoading;

  /// 선수 다음 페이지를 이어 받는 중인지 (목록 하단 스피너 표시).
  final bool playersLoadingMore;

  /// 비율 스케일. 시안(폭 375) 기준 수치에 곱한다.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isTeams = selectedTab == 0;
    final items = isTeams ? teams : players;
    final onToggle = isTeams ? onTeamToggle : onPlayerToggle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubscribedSectionHeader(label: '전체 목록', scale: scale),
        SizedBox(height: 8 * scale),
        NarTabBar(
          variant: NarTabBarVariant.compact,
          tabs: const ['팀', '선수'],
          selectedIndex: selectedTab,
          onChanged: onTabChanged,
          scale: scale,
        ),
        for (var i = 0; i < items.length; i++)
          SubscribedItemRow(
            item: items[i],
            // 짝수 index 행만 #1A1B1E 배경으로 알록달록 띠 입힘.
            backgroundColor: i.isEven ? AppColors.narBgSecondary : null,
            onToggle: onToggle == null ? null : () => onToggle(i),
            scale: scale,
          ),
        // 선수 탭: 최초 로딩(목록 빔) 또는 다음 페이지 로딩 중 스피너.
        if (!isTeams &&
            ((playersLoading && items.isEmpty) || playersLoadingMore))
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16 * scale),
            child: Center(
              child: SizedBox(
                width: 22 * scale,
                height: 22 * scale,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
