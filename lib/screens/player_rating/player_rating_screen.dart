import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import '../../components/app_bottom_sheet.dart';
import '../../components/nar_alert_dialog.dart';
import '../../components/nar_badge.dart';
import '../../components/nar_button.dart';
import '../../components/nar_detail_header.dart';
import '../../components/nar_dropdown.dart';
import '../../model/game_rating.dart';
import '../../model/match_game.dart';
import '../../repository/auth/auth_service.dart';
import '../../styles/app_colors.dart';
import '../../util/rating_mapping.dart';
import '../../viewmodel/player_rating/player_rating_viewmodel.dart';
import '../login/login_screen.dart';
import '../match_detail/component/match_detail_team_rating_section.dart';
import 'component/my_comment_card.dart';
import 'component/played_champ_card.dart';
import 'component/player_comment_section.dart';
import 'component/rating_comment_sheet.dart';
import 'component/rating_distribution_section.dart';
import 'component/subscribed_rating_banner.dart';

/// 선수 평점 상세 페이지.
///
/// 경기 상세 → 선수 평점 탭에서 선수 행을 탭하면 진입한다.
/// 헤더는 공용 [NarDetailHeader] 로 '선수 평점' 타이틀,
/// 우측 세트 드롭다운으로 세트를 전환할 수 있다.
class PlayerRatingScreen extends StatefulWidget {
  const PlayerRatingScreen({
    super.key,
    required this.player,
    required this.teamName,
    this.teamCode = '',
    required this.side,
    this.sets = const [],
    this.initialSet = '',
    required this.gameId,
    required this.participantId,
    required this.playerId,
    this.games = const [],
    this.currentSetNumber = 1,
  });

  /// 진입 시 탭한 선수.
  final PlayerRating player;

  /// 선수가 속한 팀 이름과 진영.
  final String teamName;

  /// 선수가 속한 팀의 teamCode. playerName 에 팀명 대신 팀코드가 이미 붙어
  /// 오는 응답(예: playerName='KRX Frog')의 중복 표기 판별에 쓴다.
  final String teamCode;
  final BadgeSide side;

  /// 헤더 세트 드롭다운에 노출할 세트 목록과 진입 시 선택 세트.
  final List<String> sets;
  final String initialSet;

  /// 평점 상세 로드·세트 전환에 필요한 식별자·게임 목록.
  final String gameId;
  final int participantId;
  final int playerId;
  final List<MatchGame> games;
  final int currentSetNumber;

  @override
  State<PlayerRatingScreen> createState() => _PlayerRatingScreenState();
}

class _PlayerRatingScreenState extends State<PlayerRatingScreen> {
  late String _currentSet = widget.initialSet;
  final ScrollController _scrollController = ScrollController();

  late final PlayerRatingViewModel _vm = PlayerRatingViewModel(
    gameId: widget.gameId,
    participantId: widget.participantId,
    playerId: widget.playerId,
    games: widget.games,
    currentSet: widget.currentSetNumber,
  );

  @override
  void initState() {
    super.initState();
    _vm.load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _vm.loadMoreReviews();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _vm.dispose();
    super.dispose();
  }

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
      final n = RegExp(r'\d+').firstMatch(selected);
      if (n != null) {
        _vm.selectSet(int.parse(n.group(0)!));
      }
      setState(() => _currentSet = selected);
    }
  }

  /// 평점·코멘트 남기기 바텀시트를 띄운다. 미로그인 시 로그인 화면으로 이동한다.
  Future<void> _openRatingSheet() async {
    final token = await AuthService.instance.jwt;
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    // 내 평점이 이미 있으면(수정) 기존 값을 채워 연다.
    final my = _vm.detail?.myRating;
    final result = await showRatingCommentSheet(
      context: context,
      teamName: widget.teamName,
      teamCode: widget.teamCode,
      playerName: widget.player.name,
      position: widget.player.position,
      initialRating: my?.rating ?? 0,
      initialComment: my?.comment,
    );
    if (result == null) return;
    try {
      await _vm.saveMyRating(result.rating.round(), result.comment);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.ratingSaveFailed)),
      );
    }
  }

  /// 내 댓글 삭제 확인 알럿을 띄운다.
  Future<void> _confirmDeleteComment() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showNarConfirmDialog(
      context: context,
      title: l.deleteMyRatingConfirm,
      message: l.deleteMyRatingMessage,
      cancelLabel: l.cancel,
      confirmLabel: l.delete,
    );
    if (ok != true) return;
    try {
      await _vm.deleteMyRating();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.ratingDeleteFailed)),
      );
    }
  }

  /// 분포를 5→1점 순 정수 퍼센트 리스트로. 미로드 시 0 채움.
  List<int> _distPercents(PlayerRatingDetail? d) {
    final byScore = <int, RatingDistribution>{
      for (final e in d?.distribution ?? const <RatingDistribution>[])
        e.rating: e,
    };
    return [5, 4, 3, 2, 1]
        .map((s) => (byScore[s]?.percentage ?? 0).round())
        .toList();
  }

  /// 리뷰를 코멘트 타일 모델로 변환.
  PlayerComment _toComment(Review r) => PlayerComment(
        username: r.nickname,
        timeAgo: ratingTimeAgo(r.createdAt),
        rating: r.rating,
        comment: (r.comment != null && r.comment!.isNotEmpty) ? r.comment : null,
        profileImageUrl: r.profileImageUrl,
        teamImageUrl: r.teamImageUrl,
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더는 상단 고정.
            NarDetailHeader(
              title: l.playerRating,
              trailing: NarDropdown(
                variant: NarDropdownVariant.round,
                value: _currentSet,
                onTap: _showSetSheet,
                scale: scale,
              ),
              scale: scale,
            ),
            // 나머지 콘텐츠는 스크롤. 뷰모델 상태로 렌더한다.
            Expanded(
              child: ListenableBuilder(
                listenable: _vm,
                builder: (context, _) {
                  final d = _vm.detail;
                  final my = d?.myRating;
                  return SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 28 * scale),
                        PlayedChampCard(
                          teamName: widget.teamName,
                          teamCode: widget.teamCode,
                          playerName: widget.player.name,
                          position: widget.player.position,
                          championName: d?.player.championName ?? '',
                          kda: d?.player.kda ?? '-',
                          playerImageUrl: (d?.player.playerImageUrl.isNotEmpty ??
                                  false)
                              ? d!.player.playerImageUrl
                              : widget.player.playerImageUrl,
                          scale: scale,
                        ),
                        SizedBox(height: 16 * scale),
                        RatingDistributionSection(
                          rating: d?.averageRating ?? widget.player.rating,
                          raterCount: d?.ratingCount ?? widget.player.raterCount,
                          distribution: _distPercents(d),
                          scale: scale,
                        ),
                        SizedBox(height: 16 * scale),
                        // 평점 상태별 노출:
                        // - 내 평점 있음 → 내 댓글 카드
                        // - 없음 + 구독 선수 → 구독 평점 유도 배너
                        // - 없음 + 비구독 → '평점 남기기' 버튼
                        if (my != null)
                          Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 10 * scale),
                            child: MyCommentCard(
                              username: l.me,
                              timeAgo: '',
                              rating: my.rating,
                              comment: my.comment,
                              profileImageUrl: _vm.myProfileImageUrl,
                              teamImageUrl: _vm.myTeamImageUrl,
                              onEdit: _openRatingSheet,
                              onDelete: _confirmDeleteComment,
                              scale: scale,
                            ),
                          )
                        else if (_vm.isSubscribed)
                          SubscribedRatingBanner(
                            teamName: widget.teamName,
                            teamCode: widget.teamCode,
                            playerName: widget.player.name,
                            onRate: (d?.rateable ?? false)
                                ? _openRatingSheet
                                : null,
                            scale: scale,
                          )
                        else
                          Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 10 * scale),
                            child: NarButton(
                              variant: NarButtonVariant.set1,
                              label: l.leaveRating,
                              onPressed: (d?.rateable ?? false)
                                  ? _openRatingSheet
                                  : null,
                              scale: scale,
                            ),
                          ),
                        // 평점·코멘트 리스트 — 양옆 19.5 패딩.
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 19.5 * scale),
                          child: PlayerCommentSection(
                            comments: _vm.reviews.map(_toComment).toList(),
                            scale: scale,
                          ),
                        ),
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
