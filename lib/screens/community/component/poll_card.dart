import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/community_poll.dart';
import '../../../styles/app_colors.dart';

/// 글에 붙은 투표 카드 — 본문 아래.
///
/// - 미투표(분포 비공개): 선택지가 테두리 버튼으로, 탭 = 투표
/// - 투표함/분포 공개: 선택지마다 득표 비율 바 + 표 수. 내 선택은 보라 테두리
/// - 참여 수는 항상 표시, 비공개 상태엔 "투표하면 결과를 볼 수 있어요" 안내
///
/// 분포 숨김은 서버가 voteCount 를 null 로 잘라 보내는 것으로 보장된다 —
/// 앱은 받은 값을 그대로 그린다.
class PollCard extends StatelessWidget {
  const PollCard({
    super.key,
    required this.poll,
    required this.scale,
    required this.onVote,
  });

  final CommunityPoll poll;
  final double scale;

  /// 선택지 탭(미투표 상태에서만 불린다). null 이면 탭 비활성.
  final ValueChanged<int>? onVote;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: AppColors.narDark600,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.narLine2, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined, size: 15 * scale, color: AppColors.narViolet3),
              SizedBox(width: 5 * scale),
              Expanded(
                child: Text(
                  poll.question,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 14 * scale,
                    height: 1.45,
                    color: AppColors.narText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          for (final option in poll.options) ...[
            _option(option, scale),
            SizedBox(height: 8 * scale),
          ],
          SizedBox(height: 2 * scale),
          Text(
            _footer(l),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 11.5 * scale,
              height: 1.4,
              color: AppColors.narText2,
            ),
          ),
        ],
      ),
    );
  }

  /// "N명 참여 · 복수 선택 · X시간 후 마감 / 마감됨 · 투표하면 결과…" 조합.
  String _footer(AppLocalizations l) {
    final parts = <String>[l.communityPollParticipants(poll.totalVotes)];
    if (poll.allowMultiple) parts.add(l.communityPollMultipleBadge);
    if (poll.closed) {
      parts.add(l.communityPollClosed);
    } else if (poll.closesAt != null) {
      parts.add(l.communityPollClosesIn(_remaining(poll.closesAt!, l)));
    }
    if (!poll.resultsVisible) parts.add(l.communityPollVoteToSee);
    return parts.join(' · ');
  }

  String _remaining(DateTime closesAt, AppLocalizations l) {
    final diff = closesAt.difference(DateTime.now());
    if (diff.inHours >= 24) return l.communityPollDeadlineDays(diff.inDays);
    if (diff.inHours >= 1) return l.communityPollDeadlineHours(diff.inHours);
    return l.communityPollDeadlineHours(1); // 1시간 미만은 "1시간"으로 뭉갠다
  }

  /// 이 선택지를 지금 탭해서 투표할 수 있는가 — 마감 전 + (복수 선택이면
  /// 아직 안 고른 선택지, 단일 선택이면 아예 미투표 상태).
  bool _canVote(CommunityPollOption option) {
    if (onVote == null || poll.closed) return false;
    if (poll.allowMultiple) return !poll.myOptionIds.contains(option.id);
    return !poll.voted;
  }

  Widget _option(CommunityPollOption option, double scale) {
    final mine = poll.myOptionIds.contains(option.id);
    final canVote = _canVote(option);
    final total = poll.totalVotes;
    final count = option.voteCount;
    // 분포 공개 상태에서만 바를 그린다(비공개면 count 가 null 이라 0 처리).
    final ratio = (poll.resultsVisible && total > 0 && count != null)
        ? count / total
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canVote ? () => onVote!(option.id) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9 * scale),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: AppColors.narDark500),
            ),
            // 득표 비율 바 — 왼쪽에서 채운다.
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  color: mine
                      ? AppColors.narViolet3.withValues(alpha: 0.45)
                      : AppColors.narDark400,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 10 * scale,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9 * scale),
                border: Border.all(
                  color: mine ? AppColors.narViolet3 : AppColors.narLine2,
                  width: mine ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13 * scale,
                        height: 1.45,
                        color: AppColors.narText,
                      ),
                    ),
                  ),
                  if (mine) ...[
                    Icon(Icons.check_circle,
                        size: 14 * scale, color: AppColors.narViolet3),
                    SizedBox(width: 5 * scale),
                  ],
                  if (poll.resultsVisible && count != null)
                    Text(
                      total > 0
                          ? '${(count * 100 / total).round()}%'
                          : '0%',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 12 * scale,
                        height: 1.4,
                        color: AppColors.narText2,
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
