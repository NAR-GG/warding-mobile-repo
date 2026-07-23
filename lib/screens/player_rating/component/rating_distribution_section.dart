import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../components/nar_star_rating.dart';
import '../../../styles/app_colors.dart';

/// 선수 평점 상세 — 평균 평점 + 점수별 분포 섹션.
///
/// padding 20, 좌우 space-between, 하단 정렬.
/// - 좌측: 평균 평점 숫자(32px) / 별점(20) / '총 N명 참여'
/// - 우측: 5→1 점수별 분포 바(노랑 채움 + 우측 퍼센트)
class RatingDistributionSection extends StatelessWidget {
  const RatingDistributionSection({
    super.key,
    required this.rating,
    required this.raterCount,
    required this.distribution,
    this.scale = 1,
  });

  /// 평균 평점(0~5)과 참여 인원.
  final double rating;
  final int raterCount;

  /// 5점→1점 순서의 점수별 비율(%). 길이 5(예: [90, 10, 0, 0, 0]).
  final List<int> distribution;

  final double scale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.all(20 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 좌측: 평균 평점 요약.
          SizedBox(
            width: 116 * scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                    fontSize: 32 * scale,
                    height: 1.45,
                    color: AppColors.narText,
                  ),
                ),
                SizedBox(height: 1 * scale),
                NarStarRating(rating: rating, starSize: 20, scale: scale),
                SizedBox(height: 1 * scale),
                Text(
                  l.totalParticipants(raterCount),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 14 * scale,
                    height: 1.4,
                    color: AppColors.narText2,
                  ),
                ),
              ],
            ),
          ),
          // 우측: 점수별 분포 바(5→1).
          SizedBox(
            width: 204 * scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < distribution.length; i++)
                  _DistributionRow(
                    score: 5 - i,
                    percent: distribution[i],
                    scale: scale,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 분포 한 줄: 점수 라벨 + 트랙 바(노랑 채움) + 퍼센트.
class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.score,
    required this.percent,
    required this.scale,
  });

  final int score;
  final int percent;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16 * scale,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 점수 라벨.
          SizedBox(
            width: 10 * scale,
            child: Text(
              '$score',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                fontSize: 11 * scale,
                height: 1.45,
                color: AppColors.narText,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          // 트랙 바 + 노랑 채움(percent 비율).
          Container(
            width: 150 * scale,
            height: 4 * scale,
            decoration: BoxDecoration(
              color: AppColors.narLine2,
              borderRadius: BorderRadius.circular(5 * scale),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.narYellow6,
                  borderRadius: BorderRadius.circular(5 * scale),
                ),
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          // 퍼센트.
          SizedBox(
            width: 28 * scale,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 11 * scale,
                height: 1.45,
                color: AppColors.narText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
