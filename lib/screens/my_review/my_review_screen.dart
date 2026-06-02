import 'package:flutter/material.dart';

import '../../components/nar_alert_dialog.dart';
import '../../components/nar_badge.dart';
import '../../components/nar_detail_header.dart';
import '../../styles/app_colors.dart';
import '../match_detail/component/match_detail_team_rating_section.dart';
import '../player_rating/player_rating_screen.dart';
import 'component/review_card.dart';

/// 내 리뷰/평점 화면.
///
/// 마이페이지 '내 리뷰/평점' 행에서 진입한다.
/// 헤더는 공용 [NarDetailHeader] 로 chevron-left 뒤로가기 + '내 리뷰/평점' 타이틀.
class MyReviewScreen extends StatelessWidget {
  const MyReviewScreen({super.key});

  // TODO: API 연결 후 실제 리뷰 목록으로 교체 (현재 mock). 날짜별 그룹.
  static const List<({String date, List<MyReview> reviews})> _groups = [
    (
      date: '2025.04.20',
      reviews: [
        MyReview(
          league: 'LCK 2025 스프링',
          teamName: 'T1',
          playerName: 'Faker',
          position: '미드',
          side: BadgeSide.blue,
          username: '전데요',
          timeAgo: '방금',
          rating: 5,
          raterCount: 23,
        ),
      ],
    ),
    (
      date: '2025.04.19',
      reviews: [
        MyReview(
          league: 'LCK 2025 스프링',
          teamName: 'T1',
          playerName: 'Faker',
          position: '미드',
          side: BadgeSide.blue,
          username: '전데요',
          timeAgo: '방금',
          rating: 5,
          raterCount: 23,
          comment: '역시 페이커 갈리오.',
        ),
        MyReview(
          league: 'LCK 2025 스프링',
          teamName: 'T1',
          playerName: 'Faker',
          position: '미드',
          side: BadgeSide.blue,
          username: '전데요',
          timeAgo: '방금',
          rating: 5,
          raterCount: 23,
          comment: '역시 페이커 갈리오.',
        ),
      ],
    ),
  ];

  /// 리뷰보기 — 선수 평점 페이지로 이동.
  void _openPlayerRating(BuildContext context, MyReview review) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => PlayerRatingScreen(
              player: PlayerRating(
                name: review.playerName,
                position: review.position,
                rating: review.rating,
                raterCount: review.raterCount,
              ),
              teamName: review.teamName,
              side: review.side,
            ),
      ),
    );
  }

  /// 리뷰삭제 — 선수 평점의 '내 평점 삭제' 확인 팝업(공용 컴포넌트 재사용).
  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showNarConfirmDialog(
      context: context,
      title: '내 평점을 삭제하시겠습니까?',
      message: '삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다.',
      cancelLabel: '취소',
      confirmLabel: '삭제',
    );
    if (ok != true) return;
    // TODO: API 연결 후 리뷰 삭제 요청.
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NarDetailHeader(
              title: '내 리뷰/평점',
              backIconAsset: 'assets/icons/chevron-left.svg',
              scale: scale,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 누적 리뷰/평점 바 — 타이틀 + 건수(그라데이션 텍스트).
                    _CumulativeReviewBar(
                      // TODO: 실제 누적 건수로 교체 (현재 mock).
                      count: 3,
                      scale: scale,
                    ),
                    // 날짜별 그룹 — 그룹 사이 16 간격.
                    for (var g = 0; g < _groups.length; g++) ...[
                      SizedBox(height: 16 * scale),
                      // 그룹 내부: 일자 헤더 + 카드들, 사이 2 간격.
                      ReviewDateHeader(date: _groups[g].date, scale: scale),
                      for (final review in _groups[g].reviews) ...[
                        SizedBox(height: 2 * scale),
                        ReviewCard(
                          review: review,
                          scale: scale,
                          onView: () => _openPlayerRating(context, review),
                          onDelete: () => _confirmDelete(context),
                        ),
                      ],
                    ],
                    SizedBox(height: 24 * scale),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 누적 리뷰/평점 바 (padding 10/20, 높이 45, narDark600 배경).
///
/// '누적 리뷰/평점' 라벨 + 'N건'(narBg 그라데이션 텍스트).
class _CumulativeReviewBar extends StatelessWidget {
  const _CumulativeReviewBar({required this.count, required this.scale});

  final int count;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45 * scale,
      color: AppColors.narDark600,
      padding: EdgeInsets.symmetric(
        horizontal: 20 * scale,
        vertical: 10 * scale,
      ),
      child: Row(
        children: [
          Text(
            '누적 리뷰/평점',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              fontSize: 14 * scale,
              height: 25 / 14,
              color: AppColors.narText,
            ),
          ),
          SizedBox(width: 8 * scale),
          // 'N건' — narBg 그라데이션 텍스트.
          ShaderMask(
            shaderCallback: (bounds) => AppColors.narBg.createShader(bounds),
            child: Text(
              '$count건',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                fontSize: 14 * scale,
                height: 25 / 14,
                // ShaderMask 가 덮어쓰므로 흰색이어야 그라데이션이 보인다.
                color: AppColors.narText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
