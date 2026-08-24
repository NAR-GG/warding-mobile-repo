import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/community_poll.dart';
import '../../../styles/app_colors.dart';

/// 글 상세의 투표 위젯.
///
/// 결과 공개 시점은 작성자가 정한다([CommunityPoll.hideResultsUntilVoted]).
/// 기본은 투표 후 공개 — 결과를 먼저 보여주면 앞선 표에 끌려가는 밴드왜건이
/// 생긴다.
class PollView extends StatelessWidget {
  const PollView({
    super.key,
    required this.poll,
    required this.scale,
    required this.onVote,
  });

  final CommunityPoll poll;
  final double scale;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 14 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.narBgSecondary,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine2, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 14 * scale,
              height: 1.45,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 10 * scale),
          for (var i = 0; i < poll.options.length; i++) ...[
            if (i > 0) SizedBox(height: 7 * scale),
            _Option(
              label: poll.options[i].label,
              ratio: poll.ratio(i),
              revealed: poll.resultsVisible,
              picked: poll.myChoice == i,
              scale: scale,
              onTap: poll.voted ? null : () => onVote(i),
            ),
          ],
          SizedBox(height: 9 * scale),
          Text(
            poll.voted || !poll.hideResultsUntilVoted
                ? l.communityPollVoted(poll.totalVotes)
                : l.communityPollPrompt(poll.totalVotes),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 11 * scale,
              height: 1.45,
              color: AppColors.narText2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.ratio,
    required this.revealed,
    required this.picked,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final double ratio;
  final bool revealed;
  final bool picked;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8 * scale),
        child: Stack(
          children: [
            // 득표 막대. 투표 전에는 폭 0 이라 보이지 않는다.
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: revealed ? ratio.clamp(0.0, 1.0) : 0.0,
                child: Container(
                  color: picked
                      ? AppColors.narChipSelectedBg
                      : AppColors.narChipBadgeBg,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 10 * scale,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8 * scale),
                border: Border.all(
                  color: picked ? AppColors.narChipActive : AppColors.narLine2,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13 * scale,
                        height: 1.45,
                        color: AppColors.narText,
                      ),
                    ),
                  ),
                  if (revealed)
                    Text(
                      '${(ratio * 100).round()}%',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 12 * scale,
                        height: 1.45,
                        color: AppColors.narText2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
