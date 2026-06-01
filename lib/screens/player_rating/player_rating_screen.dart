import 'package:flutter/material.dart';

import '../../components/app_bottom_sheet.dart';
import '../../components/nar_alert_dialog.dart';
import '../../components/nar_badge.dart';
import '../../styles/app_colors.dart';
import '../match_detail/component/match_detail_header.dart';
import '../match_detail/component/match_detail_team_rating_section.dart';
import 'component/my_comment_card.dart';
import 'component/played_champ_card.dart';
import 'component/player_comment_section.dart';
import 'component/rating_comment_sheet.dart';
import 'component/rating_distribution_section.dart';

/// 선수 평점 상세 페이지.
///
/// 경기 상세 → 선수 평점 탭에서 선수 행을 탭하면 진입한다.
/// 헤더는 경기 상세와 동일한 레이아웃([MatchDetailHeader])을 쓰되 타이틀만 '선수 평점',
/// 우측 세트 드롭다운으로 세트를 전환할 수 있다.
class PlayerRatingScreen extends StatefulWidget {
  const PlayerRatingScreen({
    super.key,
    required this.player,
    required this.teamName,
    required this.side,
    this.sets = const [],
    this.initialSet = '',
  });

  /// 진입 시 탭한 선수.
  final PlayerRating player;

  /// 선수가 속한 팀 이름과 진영.
  final String teamName;
  final BadgeSide side;

  /// 헤더 세트 드롭다운에 노출할 세트 목록과 진입 시 선택 세트.
  final List<String> sets;
  final String initialSet;

  @override
  State<PlayerRatingScreen> createState() => _PlayerRatingScreenState();
}

class _PlayerRatingScreenState extends State<PlayerRatingScreen> {
  late String _currentSet = widget.initialSet;

  /// 헤더의 세트 드롭다운 탭 시 호출. 세트 목록 바텀시트를 띄우고 선택값으로 갱신.
  Future<void> _showSetSheet() async {
    if (widget.sets.isEmpty) return;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final selected = await showAppBottomSheet<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final setLabel in widget.sets)
            InkWell(
              onTap: () => Navigator.of(context).pop(setLabel),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 14 * scale,
                ),
                child: Text(
                  setLabel,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight:
                        setLabel == _currentSet
                            ? FontWeight.w600
                            : FontWeight.w400,
                    fontSize: 16 * scale,
                    color:
                        setLabel == _currentSet
                            ? AppColors.narText
                            : AppColors.narText2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (selected != null && selected != _currentSet) {
      setState(() => _currentSet = selected);
    }
  }

  /// 평점·코멘트 남기기 바텀시트를 띄운다.
  Future<void> _openRatingSheet() async {
    final result = await showRatingCommentSheet(
      context: context,
      teamName: widget.teamName,
      playerName: widget.player.name,
      position: widget.player.position,
    );
    if (result == null) return;
    // TODO: API 연결 후 평점·코멘트 등록 요청 (result.rating, result.comment).
  }

  /// 내 댓글 삭제 확인 알럿을 띄운다.
  Future<void> _confirmDeleteComment() async {
    final ok = await showNarConfirmDialog(
      context: context,
      title: '내 평점을 삭제하시겠습니까?',
      message: '삭제된 댓글은 복구되지 않습니다. 댓글은 수정 기능을 통해 편집할 수 있습니다.',
      cancelLabel: '취소',
      confirmLabel: '삭제',
    );
    if (ok != true) return;
    // TODO: API 연결 후 내 평점·댓글 삭제 요청.
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
            // 헤더는 상단 고정.
            MatchDetailHeader(
              title: '선수 평점',
              setLabel: _currentSet,
              onSetTap: _showSetSheet,
              scale: scale,
            ),
            // 나머지 콘텐츠는 스크롤.
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 28 * scale),
                    PlayedChampCard(
                      teamName: widget.teamName,
                      playerName: widget.player.name,
                      position: widget.player.position,
                      // TODO: API 연결 후 실제 KDA로 교체 (현재 mock).
                      kda: '4/1/7',
                      scale: scale,
                    ),
                    SizedBox(height: 16 * scale),
                    RatingDistributionSection(
                      rating: widget.player.rating,
                      raterCount: widget.player.raterCount,
                      // TODO: API 연결 후 실제 점수별 분포로 교체 (현재 mock, 5→1점).
                      distribution: const [90, 10, 0, 0, 0],
                      scale: scale,
                    ),
                    SizedBox(height: 16 * scale),
                    // 내 댓글 카드 — 양옆 10 패딩.
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                      child: MyCommentCard(
                        // TODO: API 연결 후 실제 내 평점·댓글로 교체 (현재 mock).
                        username: '전데요',
                        timeAgo: '방금',
                        rating: 4.5,
                        onEdit: _openRatingSheet,
                        onDelete: _confirmDeleteComment,
                        scale: scale,
                      ),
                    ),
                    // 평점·코멘트 리스트 — 양옆 19.5 패딩.
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 19.5 * scale),
                      child: PlayerCommentSection(
                        // TODO: API 연결 후 실제 코멘트로 교체 (현재 mock).
                        comments: const [
                          PlayerComment(
                            username: 'Faker_팬티도둑',
                            timeAgo: '2시간 전',
                            rating: 4.5,
                            comment: '역시 페이커 갈리오.',
                          ),
                          PlayerComment(
                            username: 'Faker_팬',
                            timeAgo: '2시간 전',
                            rating: 5.0,
                            comment: '페이커 오늘도 수고했어요! 다음 경기도 화이팅!!',
                          ),
                          PlayerComment(
                            username: '안녕하세요',
                            timeAgo: '2시간 전',
                            rating: 4.5,
                          ),
                        ],
                        scale: scale,
                      ),
                    ),
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
