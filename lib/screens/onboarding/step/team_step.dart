import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import '../../../viewmodel/onboarding/onboarding_viewmodel.dart';
import '../component/onboarding_load_error.dart';
import '../component/onboarding_select_card.dart';
import '../component/onboarding_title.dart';

/// 선호 팀 선택 단계 (View).
///
/// 팀 목록·선택 상태는 [OnboardingViewModel] 에서 가져온다.
class TeamStep extends StatelessWidget {
  const TeamStep({
    super.key,
    required this.viewModel,
    this.scale = 1.0,
  });

  final OnboardingViewModel viewModel;

  /// 디자인 시안 대비 스케일.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 48 * scale),
        OnboardingTitle(
          mainTitle: '가장 응원하는 팀을 선택해주세요',
          subTitle: 'LCK 국내 팀 기준입니다.',
          scale: scale,
        ),
        SizedBox(height: 32 * scale), // 타이틀 ↔ 그리드 고정 간격 (스크롤해도 유지)
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildGrid() {
    if (viewModel.teamsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.teamsError != null) {
      return OnboardingLoadError(
        message: '팀 목록을 불러오지 못했어요',
        error: viewModel.teamsError!,
        onRetry: viewModel.loadTeams,
      );
    }

    return GridView.count(
      padding: EdgeInsets.fromLTRB(60 * scale, 0, 60 * scale, 0),
      crossAxisCount: 2,
      childAspectRatio: 119 / 152,
      crossAxisSpacing: 16 * scale,
      mainAxisSpacing: 16 * scale,
      children: [
        for (final team in viewModel.teams)
          OnboardingSelectCard(
            scale: scale,
            selected: team.id == viewModel.selectedTeamId,
            image: Image.network(
              team.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.shield_outlined,
                color: AppColors.narText2,
              ),
            ),
            mainTitle: team.name,
            onTap: () => viewModel.selectTeam(team.id),
          ),
      ],
    );
  }
}
