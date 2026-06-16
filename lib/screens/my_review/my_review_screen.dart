import 'package:flutter/material.dart';

import '../../components/nar_alert_dialog.dart';
import '../../components/nar_badge.dart';
import '../../components/nar_detail_header.dart';
import '../../model/my_rating_list.dart';
import '../../styles/app_colors.dart';
import '../../util/rating_mapping.dart';
import '../../viewmodel/my_review/my_review_viewmodel.dart';
import '../match_detail/component/match_detail_team_rating_section.dart';
import '../player_rating/player_rating_screen.dart';
import 'component/review_card.dart';

/// 내 리뷰/평점 화면.
///
/// 마이페이지 '내 리뷰/평점' 행에서 진입한다.
/// 헤더는 공용 [NarDetailHeader] 로 chevron-left 뒤로가기 + '내 리뷰/평점' 타이틀.
class MyReviewScreen extends StatefulWidget {
  const MyReviewScreen({super.key});

  @override
  State<MyReviewScreen> createState() => _MyReviewScreenState();
}

class _MyReviewScreenState extends State<MyReviewScreen> {
  final MyReviewViewModel _vm = MyReviewViewModel();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm.load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _vm.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// 응답 항목을 기존 ReviewCard 입력(MyReview)으로 변환.
  MyReview _toReview(MyRatingItem item) => MyReview(
        league: item.match?.leagueName ?? '',
        teamName: item.match == null
            ? ''
            : (sideFromTeamSide(item.teamSide) == BadgeSide.blue
                ? item.match!.blueTeamCode
                : item.match!.redTeamCode),
        playerName: item.playerName,
        position: positionFromRole(item.role),
        side: sideFromTeamSide(item.teamSide),
        username: '나',
        timeAgo: ratingTimeAgo(item.createdAt),
        rating: item.rating.toDouble(),
        comment: (item.comment != null && item.comment!.isNotEmpty)
            ? item.comment
            : null,
      );

  /// 리뷰보기 — 선수 평점 상세로 이동. 돌아오면 목록을 다시 불러온다
  /// (상세에서 평가를 수정·삭제했을 수 있으므로).
  Future<void> _openPlayerRating(MyRatingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerRatingScreen(
          player: PlayerRating(
            name: item.playerName,
            position: positionFromRole(item.role),
            rating: item.rating.toDouble(),
            raterCount: 0,
            participantId: item.participantId,
            playerId: item.playerId,
          ),
          teamName: item.match == null
              ? ''
              : (sideFromTeamSide(item.teamSide) == BadgeSide.blue
                  ? item.match!.blueTeamCode
                  : item.match!.redTeamCode),
          side: sideFromTeamSide(item.teamSide),
          gameId: item.gameId,
          participantId: item.participantId,
          playerId: item.playerId,
        ),
      ),
    );
    if (mounted) _vm.load();
  }

  /// 리뷰삭제 — 확인 후 VM 삭제.
  Future<void> _confirmDelete(MyRatingItem item) async {
    final ok = await showNarConfirmDialog(
      context: context,
      title: '내 평점을 삭제하시겠습니까?',
      message: '삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다.',
      cancelLabel: '취소',
      confirmLabel: '삭제',
    );
    if (ok != true) return;
    try {
      await _vm.deleteRating(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제에 실패했어요. 잠시 후 다시 시도해주세요.')),
      );
    }
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
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) {
                  final groups = _vm.grouped;
                  return SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CumulativeReviewBar(
                          count: _vm.totalElements,
                          scale: scale,
                        ),
                        for (final entry in groups.entries) ...[
                          SizedBox(height: 16 * scale),
                          ReviewDateHeader(date: entry.key, scale: scale),
                          for (final item in entry.value) ...[
                            SizedBox(height: 2 * scale),
                            ReviewCard(
                              review: _toReview(item),
                              scale: scale,
                              onView: () => _openPlayerRating(item),
                              onDelete: () => _confirmDelete(item),
                            ),
                          ],
                        ],
                        SizedBox(height: 24 * scale),
                      ],
                    ),
                  );
                },
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
