import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/nar_detail_header.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_comment.dart';
import '../../model/community_post.dart';
import '../../styles/app_colors.dart';
import 'community_dummy.dart';
import 'community_permission.dart';
import 'community_teams.dart';
import 'component/author_line.dart';
import 'component/comment_tile.dart';
import 'component/community_image.dart';
import 'component/poll_view.dart';
import 'component/report_sheet.dart';

/// 글 상세 — 본문 · 추천/스크랩 · 댓글(1단 답글) · 댓글 입력.
///
/// 쓰기 권한이 없는 게시판이면 본문과 댓글은 그대로 읽히고 입력창만 잠긴다.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final CommunityPost post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late CommunityPost _post = widget.post;
  late List<CommunityComment> _comments = [...kDummyComments];

  /// 답글이 펼쳐진 최상위 댓글 id. 기본은 전부 접힘.
  final Set<int> _expanded = <int>{};

  final TextEditingController _comment = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _comment.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 액션 행의 '댓글'을 누르면 입력창으로 커서를 옮겨 키보드를 올린다.
  /// 목록 맨 아래까지 같이 내려줘야 방금 쓸 자리가 보인다.
  Future<void> _focusComment() async {
    if (!_canWrite) return;
    _commentFocus.requestFocus();

    // 키보드가 올라오면서 본문 영역이 줄어드는데, 그 전에 스크롤하면 줄어들기
    // 전 기준의 maxScrollExtent 로 가서 결국 중간에 멈춘다. 애니메이션이
    // 끝난 뒤에 맨 아래로 붙인다.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  bool get _canWrite => canWriteToBoard(
    loggedIn: kDummyLoggedIn,
    myTeamId: kDummyMyTeamId,
    boardId: _post.boardId,
  );

  void _toggleLike() {
    setState(() {
      _post = _post.copyWith(
        liked: !_post.liked,
        likeCount: _post.likeCount + (_post.liked ? -1 : 1),
      );
    });
  }

  void _toggleScrap() {
    setState(() => _post = _post.copyWith(scrapped: !_post.scrapped));
  }

  void _toggleCommentLike(CommunityComment comment) {
    setState(() {
      _comments = [
        for (final c in _comments)
          if (c.id == comment.id)
            c.copyWith(
              liked: !c.liked,
              likeCount: c.likeCount + (c.liked ? -1 : 1),
            )
          else
            c,
      ];
    });
  }

  /// `⋯` → 더보기 → (신고면) 사유 선택. 글과 댓글이 같은 흐름을 쓴다.
  Future<void> _openMore() async {
    final l = AppLocalizations.of(context)!;
    final action = await showCommunityMoreSheet(context);
    if (!mounted || action == null) return;

    if (action == CommunityMoreAction.block) {
      _toast(l.communityBlockDone);
      return;
    }
    final reason = await showReportReasonSheet(context);
    if (!mounted || reason == null) return;
    _toast(l.communityReportDone);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final scale = width.clamp(320.0, 430.0) / 375;
    final board = dummyBoard(_post.boardId);
    final roots = _comments.where((c) => c.parentId == null).toList();

    return Scaffold(
      backgroundColor: AppColors.narDark800,
      // 키보드가 올라온 상태에서 아무 데나 누르면 내려간다. translucent 라
      // 목록 항목·버튼의 탭은 그대로 각자에게 간다.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              NarDetailHeader(
                title: board.isAll
                    ? l.communityBoardAll
                    : l.communityBoardTeam(boardDisplayName(board)),
                scale: scale,
                trailing: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openMore,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                    child: SvgPicture.asset(
                      'assets/icons/dots.svg',
                      width: 18 * scale,
                      height: 18 * scale,
                      colorFilter: const ColorFilter.mode(
                        AppColors.narText3,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  // 목록을 끌어내려도 키보드가 닫힌다.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(bottom: 24 * scale),
                  children: [
                    _body(l, scale),
                    _actions(l, scale),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20 * scale,
                        14 * scale,
                        20 * scale,
                        2 * scale,
                      ),
                      child: Text(
                        l.communityCommentCount(_post.commentCount),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w700,
                          fontSize: 13 * scale,
                          height: 1.45,
                          color: AppColors.narText,
                        ),
                      ),
                    ),
                    for (final root in roots) ..._thread(root, scale),
                  ],
                ),
              ),
              _inputBar(l, scale, board),
            ],
          ),
        ),
      ),
    );
  }

  /// 최상위 댓글 + (펼쳤을 때) 그 답글들.
  List<Widget> _thread(CommunityComment root, double scale) {
    final replies = _comments.where((c) => c.parentId == root.id).toList();
    final expanded = _expanded.contains(root.id);

    return [
      CommentTile(
        comment: root,
        scale: scale,
        isReply: false,
        onLike: () => _toggleCommentLike(root),
        onReply: () => setState(() => _expanded.add(root.id)),
        onMore: _openMore,
      ),
      if (replies.isNotEmpty) ...[
        ReplyToggle(
          count: replies.length,
          expanded: expanded,
          scale: scale,
          onTap: () => setState(() {
            if (!_expanded.remove(root.id)) _expanded.add(root.id);
          }),
        ),
        if (expanded)
          for (final reply in replies)
            CommentTile(
              comment: reply,
              scale: scale,
              isReply: true,
              onLike: () => _toggleCommentLike(reply),
              onReply: () {},
              onMore: _openMore,
            ),
      ],
    ];
  }

  Widget _body(AppLocalizations l, double scale) {
    final poll = _post.poll;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20 * scale,
        14 * scale,
        20 * scale,
        16 * scale,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.narLine, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 → 제목 → 본문 순. 글을 열자마자 "누가 썼는지"가 먼저 잡혀야
          // 팀 로고를 보고 읽는 태도를 정할 수 있다.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34 * scale,
                height: 34 * scale,
                decoration: const BoxDecoration(
                  color: AppColors.narDark400,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 9 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthorLine(
                      name: _post.authorName,
                      teamId: _post.authorTeamId,
                      scale: scale,
                      fontSize: 13,
                      logoSize: 14,
                      color: AppColors.narText,
                    ),
                    Text(
                      '${_post.timeAgo} · ${l.communityViewCount(_post.viewCount)}',
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
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Text(
            _post.title,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              fontSize: 18 * scale,
              height: 1.4,
              color: AppColors.narText,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            _post.body,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              fontSize: 14 * scale,
              height: 1.65,
              color: AppColors.narText3,
            ),
          ),
          if (poll != null) ...[
            SizedBox(height: 16 * scale),
            PollView(
              poll: poll,
              scale: scale,
              onVote: (i) =>
                  setState(() => _post = _post.copyWith(poll: poll.vote(i))),
            ),
          ],
          if (_post.images.isNotEmpty) ...[
            SizedBox(height: 14 * scale),
            // 사진은 세로로 쌓는다. 캐러셀은 몇 장인지 안 보여서 첨부 수가
            // 적은 커뮤니티 글에는 스크롤로 지나가는 편이 낫다.
            for (var i = 0; i < _post.images.length; i++) ...[
              if (i > 0) SizedBox(height: 8 * scale),
              CommunityImage(
                source: _post.images[i],
                width: double.infinity,
                height: 200 * scale,
                radius: 10 * scale,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 추천·댓글·스크랩을 폭 3등분으로 꽉 채운다. 칩으로 왼쪽에 몰아두면 본문과
  /// 댓글 사이의 경계가 흐려지는데, 균등 분할하면 그 자체가 구분선 역할을 한다.
  Widget _actions(AppLocalizations l, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4 * scale),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.narLine, width: 1),
          bottom: BorderSide(color: AppColors.narLine, width: 1),
        ),
      ),
      child: Row(
        children: [
          _ActionCell(
            asset: _post.liked
                ? 'assets/icons/thumb-up-filled.svg'
                : 'assets/icons/thumb-up.svg',
            label: _post.likeCount == 0
                ? l.communityLike
                : '${l.communityLike} ${_post.likeCount}',
            active: _post.liked,
            scale: scale,
            onTap: _toggleLike,
          ),
          _ActionCell(
            asset: 'assets/icons/message-circle.svg',
            label: l.communityCommentCount(_post.commentCount),
            active: false,
            scale: scale,
            onTap: _focusComment,
          ),
          _ActionCell(
            asset: 'assets/icons/bookmark.svg',
            label: l.communityScrap,
            active: _post.scrapped,
            scale: scale,
            onTap: _toggleScrap,
          ),
        ],
      ),
    );
  }

  /// 댓글 입력 바. 키보드가 올라오면 Scaffold 가 본문을 줄여 이 바를 그
  /// 위로 밀어 올린다(`resizeToAvoidBottomInset` 기본값).
  Widget _inputBar(AppLocalizations l, double scale, CommunityBoard board) {
    final locked = !_canWrite;
    final ready = _comment.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        10 * scale,
        16 * scale,
        12 * scale,
      ),
      decoration: const BoxDecoration(
        color: AppColors.narDark800,
        border: Border(top: BorderSide(color: AppColors.narLine, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: 40 * scale),
              padding: EdgeInsets.symmetric(horizontal: 14 * scale),
              decoration: BoxDecoration(
                color: locked ? null : AppColors.narDark600,
                borderRadius: BorderRadius.circular(20 * scale),
                border: Border.all(
                  color: locked ? AppColors.narDark400 : AppColors.narLine2,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _comment,
                focusNode: _commentFocus,
                enabled: !locked,
                minLines: 1,
                maxLines: 4,
                cursorColor: AppColors.narViolet3,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  fontSize: 13 * scale,
                  height: 1.45,
                  color: AppColors.narText,
                ),
                decoration: InputDecoration(
                  hintText: locked
                      ? l.communityCommentLocked(boardDisplayName(board))
                      : l.communityCommentHint,
                  hintStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    fontSize: 13 * scale,
                    height: 1.45,
                    color: locked ? AppColors.narDark300 : AppColors.narText2,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10 * scale),
                ),
              ),
            ),
          ),
          SizedBox(width: 10 * scale),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ready ? _submitComment : null,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10 * scale),
              child: Text(
                l.communityCommentSubmit,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: 13 * scale,
                  height: 1.45,
                  color: ready ? AppColors.narViolet3 : AppColors.narDark300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 더미라 서버로 보내지 않고 목록 맨 아래에 바로 붙인다.
  void _submitComment() {
    final text = _comment.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments = [
        ..._comments,
        CommunityComment(
          id: DateTime.now().microsecondsSinceEpoch,
          parentId: null,
          authorName: '나',
          authorTeamId: kDummyMyTeamId,
          body: text,
          timeAgo: '방금 전',
          likeCount: 0,
        ),
      ];
      _post = _post.copyWith(commentCount: _post.commentCount + 1);
      _comment.clear();
    });
    _commentFocus.unfocus();
  }
}

/// 액션 행의 한 칸. 셋이 폭을 정확히 3등분한다.
class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.asset,
    required this.label,
    required this.active,
    required this.scale,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool active;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.narTextRed : AppColors.narText2;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12 * scale),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                asset,
                width: 16 * scale,
                height: 16 * scale,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              SizedBox(width: 6 * scale),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    fontSize: 13 * scale,
                    height: 1.45,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
