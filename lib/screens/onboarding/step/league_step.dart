import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

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
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 48 * scale),
        OnboardingTitle(
          mainTitle: l.favoriteLeagueQuestion,
          scale: scale,
        ),
        SizedBox(height: 32 * scale), // 타이틀 ↔ 그리드 고정 간격 (스크롤해도 유지)
        Expanded(child: _buildGrid(context)),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (viewModel.leaguesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.leaguesError != null) {
      return OnboardingLoadError(
        message: l.leagueLoadFailed,
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
            image: CachedNetworkImage(
              imageUrl: resolveImageUrl(league.imageUrl)!,
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, _, _) => const Icon(
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
