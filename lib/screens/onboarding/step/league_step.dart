import 'package:flutter/material.dart';

import '../../../styles/app_colors.dart';
import '../../../util/app_image.dart';
import '../../../viewmodel/onboarding/onboarding_viewmodel.dart';
import '../component/onboarding_load_error.dart';
import '../component/onboarding_select_card.dart';
import '../component/onboarding_title.dart';

/// 선호 리그 선택 단계 (View).
///
/// 리그 목록·선택 상태는 [OnboardingViewModel] 에서 가져온다.
class LeagueStep extends StatelessWidget {
  const LeagueStep({
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
          mainTitle: '즐겨 시청하는 리그는 무엇인가요?',
          scale: scale,
        ),
        SizedBox(height: 32 * scale), // 타이틀 ↔ 그리드 고정 간격 (스크롤해도 유지)
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildGrid() {
    if (viewModel.leaguesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.leaguesError != null) {
      return OnboardingLoadError(
        message: '리그 목록을 불러오지 못했어요',
        error: viewModel.leaguesError!,
        onRetry: viewModel.loadLeagues,
      );
    }

    return GridView.count(
      padding: EdgeInsets.fromLTRB(60 * scale, 0, 60 * scale, 0),
      crossAxisCount: 2,
      childAspectRatio: 119 / 152,
      crossAxisSpacing: 16 * scale,
      mainAxisSpacing: 16 * scale,
      children: [
        for (final league in viewModel.leagues)
          OnboardingSelectCard(
            scale: scale,
            selected: league.name == viewModel.selectedLeagueName,
            image: Image.network(
              resolveImageUrl(league.imageUrl)!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.narText2,
              ),
            ),
            mainTitle: league.name,
            subTitle: league.regionName.isEmpty ? null : league.regionName,
            onTap: () => viewModel.selectLeague(league.name),
          ),
      ],
    );
  }
}
