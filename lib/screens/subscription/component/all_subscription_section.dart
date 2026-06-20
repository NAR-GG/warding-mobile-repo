import 'package:flutter/material.dart';

import '../../../components/nar_tab_bar.dart';
import '../../../styles/app_colors.dart';
import 'subscribed_section.dart';

/// 구독 설정 화면의 '전체 목록' 섹션.
///
/// 상단 narBgLast 헤더 바 + 8 gap + 콤팩트 탭바([팀]/[선수]) + 8 gap + 행 리스트.
/// 행은 [SubscribedItemRow] 를 재사용하며 짝수 index 행만 narBgSecondary 배경으로
/// 알록달록 띠를 입힌다.
class AllSubscriptionSection extends StatefulWidget {
  const AllSubscriptionSection({
    super.key,
    required this.teams,
    required this.players,
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
  State<AllSubscriptionSection> createState() => _AllSubscriptionSectionState();
}

class _AllSubscriptionSectionState extends State<AllSubscriptionSection> {
  /// 0: 팀, 1: 선수.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    final isTeams = _tab == 0;
    final items = isTeams ? widget.teams : widget.players;
    final onToggle = isTeams ? widget.onTeamToggle : widget.onPlayerToggle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubscribedSectionHeader(label: '전체 목록', scale: scale),
        SizedBox(height: 8 * scale),
        NarTabBar(
          variant: NarTabBarVariant.compact,
          tabs: const ['팀', '선수'],
          selectedIndex: _tab,
          onChanged: (i) => setState(() => _tab = i),
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
        if (!isTeams && ((widget.playersLoading && items.isEmpty) ||
            widget.playersLoadingMore))
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
