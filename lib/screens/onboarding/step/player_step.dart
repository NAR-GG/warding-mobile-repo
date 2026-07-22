import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../components/app_select_box.dart';
import '../../../components/labeled_field.dart';
import '../../../model/team.dart';
import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../viewmodel/onboarding/onboarding_viewmodel.dart';
import '../component/onboarding_load_error.dart';
import '../component/onboarding_select_card.dart';
import '../component/onboarding_title.dart';

/// 선호 선수 선택 단계 (View).
///
/// 상단의 '팀' 셀렉트 박스로 선수 목록의 기준 팀을 바꿀 수 있고, 그 아래
/// 그리드에서 선수를 중복 선택한다. 목록·선택 상태는 [OnboardingViewModel]
/// 에서 가져온다.
class PlayerStep extends StatefulWidget {
  const PlayerStep({
    super.key,
    required this.viewModel,
    this.scale = 1.0,
  });

  final OnboardingViewModel viewModel;

  /// 디자인 시안 대비 스케일.
  final double scale;

  @override
  State<PlayerStep> createState() => _PlayerStepState();
}

class _PlayerStepState extends State<PlayerStep> {
  /// '팀' 셀렉트 박스 드롭다운 펼침 여부. 화면에만 필요한 UI 상태.
  bool _teamDropdownOpen = false;

  OnboardingViewModel get _viewModel => widget.viewModel;
  double get scale => widget.scale;

  void _toggleTeamDropdown() {
    setState(() => _teamDropdownOpen = !_teamDropdownOpen);
  }

  void _onSelectTeam(int id) {
    setState(() => _teamDropdownOpen = false);
    _viewModel.changePlayerTeam(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 48 * scale),
        OnboardingTitle(
          mainTitle: '응원하는 선수를 선택해주세요',
          subTitle: 'LCK 국내 팀 기준입니다. (중복 가능)',
          scale: scale,
        ),
        SizedBox(height: 32 * scale), // 타이틀 ↔ 셀렉트 박스 고정 간격
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: LabeledField(
            label: '팀',
            scale: scale,
            child: _TeamSelectField(
              teams: _viewModel.teams,
              selectedTeamId: _viewModel.selectedTeamId,
              isOpen: _teamDropdownOpen,
              onTapBox: _toggleTeamDropdown,
              onSelect: _onSelectTeam,
              scale: scale,
            ),
          ),
        ),
        SizedBox(height: 27 * scale), // 셀렉트 박스 ↔ 선수 그리드 간격 27
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildGrid() {
    if (_viewModel.playersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_viewModel.playersError != null) {
      return OnboardingLoadError(
        message: '선수 목록을 불러오지 못했어요',
        onRetry: _viewModel.loadPlayers,
      );
    }
    if (_viewModel.players.isEmpty) {
      return const Center(
        child: Text(
          '선수 정보가 없어요',
          style: TextStyle(color: AppColors.narText2),
        ),
      );
    }

    return GridView.count(
      padding: EdgeInsets.fromLTRB(60 * scale, 0, 60 * scale, 0),
      crossAxisCount: 2,
      childAspectRatio: 119 / 152,
      crossAxisSpacing: 16 * scale,
      mainAxisSpacing: 16 * scale,
      children: [
        for (final player in _viewModel.players)
          OnboardingSelectCard(
            scale: scale,
            selected: _viewModel.isPlayerSelected(player.id),
            image: CachedNetworkImage(
              imageUrl: resolveImageUrl(player.imageUrl)!,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => const Icon(
                Icons.person_outline,
                color: AppColors.narText2,
              ),
            ),
            mainTitle: player.name,
            onTap: () => _viewModel.togglePlayer(player.id),
          ),
      ],
    );
  }
}

/// '팀' 셀렉트 박스 + 펼침 드롭다운 한 묶음.
///
/// 박스는 왼쪽에 팀 이름, 오른쪽에 펼침 화살표를 둔다.
/// [isOpen] 이면 박스 아래 4 간격을 띄우고 팀 드롭다운을 보여준다.
class _TeamSelectField extends StatelessWidget {
  const _TeamSelectField({
    required this.teams,
    required this.selectedTeamId,
    required this.isOpen,
    required this.onTapBox,
    required this.onSelect,
    required this.scale,
  });

  /// 드롭다운에 나열할 팀 목록.
  final List<Team> teams;

  /// 현재 선택된 팀 ID.
  final int? selectedTeamId;

  /// 드롭다운 펼침 여부.
  final bool isOpen;

  /// 박스 탭 콜백.
  final VoidCallback onTapBox;

  /// 팀 선택 콜백.
  final ValueChanged<int> onSelect;

  final double scale;

  @override
  Widget build(BuildContext context) {
    var selectedName = '팀 선택';
    for (final team in teams) {
      if (team.id == selectedTeamId) {
        selectedName = team.name;
        break;
      }
    }

    // 셀렉트 박스·드롭다운 너비는 디자인 시안 기준 200 고정, 왼쪽 정렬.
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 200 * scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSelectBox(
              text: selectedName,
              scale: scale,
              onTap: onTapBox,
              trailing: Icon(
                isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20 * scale,
                color: AppColors.narText3,
              ),
            ),
            if (isOpen) ...[
              SizedBox(height: 4 * scale), // 셀렉트 박스 ↔ 드롭다운 간격 4
              _TeamDropdownList(
                teams: teams,
                selectedTeamId: selectedTeamId,
                onSelect: onSelect,
                scale: scale,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 팀 드롭다운 목록 — 라운드 10, 배경은 셀렉트 박스와 동일. 길면 스크롤된다.
class _TeamDropdownList extends StatelessWidget {
  const _TeamDropdownList({
    required this.teams,
    required this.selectedTeamId,
    required this.onSelect,
    required this.scale,
  });

  final List<Team> teams;
  final int? selectedTeamId;
  final ValueChanged<int> onSelect;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 항목 배경이 라운드 모서리 밖으로 새지 않게 클리핑.
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxHeight: 180 * scale),
      decoration: BoxDecoration(
        color: AppColors.narBgLast, // 셀렉트 박스와 같은 #25262B
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          for (final team in teams)
            _TeamDropdownItem(
              label: team.name,
              isSelected: team.id == selectedTeamId,
              onTap: () => onSelect(team.id),
              scale: scale,
            ),
        ],
      ),
    );
  }
}

/// 팀 드롭다운 항목 한 칸 — 좌우 16·위아래 11.5 패딩.
///
/// 선택된 항목은 빨강 배경([AppColors.narRedOpacity25]) + 어두운 글자,
/// 미선택 항목은 흐린 글자만 표시한다.
class _TeamDropdownItem extends StatelessWidget {
  const _TeamDropdownItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected ? AppColors.narRedOpacity25 : null, // #FA525240
        padding: EdgeInsets.symmetric(
          horizontal: 16 * scale,
          vertical: 11.5 * scale,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w400,
            fontSize: 16 * scale,
            height: 22 / 16, // line-height 22px / font-size 16px
            letterSpacing: 0,
            color: isSelected
                ? AppColors.narButton1Text // 선택 — #101113
                : AppColors.narDark200, // 미선택 — #909296
          ),
        ),
      ),
    );
  }
}
