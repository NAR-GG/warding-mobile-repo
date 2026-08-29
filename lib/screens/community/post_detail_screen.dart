import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/nar_detail_header.dart';
import '../../components/profile_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../model/community_remote_comment.dart';
import '../../model/community_remote_post.dart';
import '../../model/community_report.dart';
import '../../styles/app_colors.dart';
import '../../util/rating_mapping.dart';
import '../../viewmodel/community/community_detail_viewmodel.dart';
import '../login/login_screen.dart';
import 'community_teams.dart';
import 'component/author_line.dart';
import 'component/comment_tile.dart';
import 'component/community_image.dart';
import 'component/community_photo_viewer.dart';
import 'component/report_sheet.dart';
import 'post_write_screen.dart';

/// 상세에서 돌아올 때 목록이 알아야 하는 것 — 추천·댓글 수가 바뀐 글, 또는
/// 삭제·차단으로 목록에서 빠져야 한다는 신호.
typedef PostDetailResult = ({CommunityRemotePost? updated, bool removed});

/// 글 상세 — 본문 · 추천/스크랩 · 댓글(1단 답글) · 댓글 입력.
///
/// 쓰기 권한이 없는 게시판이면 본문과 댓글은 그대로 읽히고 입력창만 잠긴다.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final int postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final CommunityDetailViewModel _vm = CommunityDetailViewModel(
    postId: widget.postId,
  );

  /// 답글이 펼쳐진 최상위 댓글 id. 기본은 전부 접힘.
  final Set<int> _expanded = <int>{};

  /// 답글을 달 대상. null 이면 새 댓글이다.
  CommunityRemoteComment? _replyTo;

  /// 수정 중인 내 댓글. 있으면 입력창이 수정 모드가 된다(답글 상태와 상호 배타).
  CommunityRemoteComment? _editingComment;

  final TextEditingController _comment = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  /// 목록으로 돌려줄 상태. 삭제·차단이면 목록에서 빼야 한다.
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
    _vm.load();
    _vm.addListener(_showError);
  }

  @override
  void dispose() {
    _vm.removeListener(_showError);
    _comment.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// 쓰기 실패(쿨다운·작성 간격·권한)는 서버 문구를 그대로 띄운다. 코드별로
  /// 앱이 다시 쓰면 서버가 사유를 바꿀 때마다 앱을 고쳐야 한다.
  void _showError() {
    final message = _vm.error;
    if (message == null || !mounted) return;
    _vm.clearError();
    _toast(message);
  }

  void _pop() {
    Navigator.of(context).pop<PostDetailResult>((
      updated: _removed ? null : _vm.post?.summary,
      removed: _removed,
    ));
  }

  /// 액션 행의 '댓글'을 누르면 입력창으로 커서를 옮겨 키보드를 올린다.
  /// 목록 맨 아래까지 같이 내려줘야 방금 쓸 자리가 보인다.
  Future<void> _focusComment() async {
    if (!_vm.canWrite) return;
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

  void _startReply(CommunityRemoteComment comment) {
    setState(() {
      _expanded.add(comment.parentId ?? comment.id);
      _replyTo = comment;
      _editingComment = null;
    });
    _focusComment();
  }

  /// 내 댓글 수정 — 기존 본문을 입력창에 채워 수정 모드로 전환한다.
  void _startEditComment(CommunityRemoteComment comment) {
    setState(() {
      _replyTo = null;
      _editingComment = comment;
      _comment.text = comment.body ?? '';
    });
    _focusComment();
  }

  void _cancelEditComment() {
    setState(() {
      _editingComment = null;
      _comment.clear();
    });
    _commentFocus.unfocus();
  }

  Future<void> _submitComment() async {
    final editing = _editingComment;
    final ok = editing != null
        ? await _vm.updateComment(editing.id, _comment.text)
        : await _vm.submitComment(
            _comment.text,
            replyToCommentId: _replyTo?.id,
          );
    if (!ok || !mounted) return;
    setState(() {
      _comment.clear();
      _replyTo = null;
      _editingComment = null;
    });
    _commentFocus.unfocus();
  }

  /// 내 글 수정 — 글쓰기 화면을 수정 모드로 연다. 돌아오면 상세를 다시 받는다.
  Future<void> _editPost() async {
    final post = _vm.post;
    if (post == null) return;
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) =>
            PostWriteScreen(boardTeamId: post.boardTeamId, edit: post),
      ),
    );
    if (result != null && mounted) await _vm.load();
  }

  /// 글의 `⋯`. 내 글이면 삭제, 남의 글이면 신고·차단.
  Future<void> _postMore() async {
    final post = _vm.post;
    if (post == null) return;
    final action = await showCommunityMoreSheet(
      context,
      mine: post.viewer.mine,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case CommunityMoreAction.edit:
        await _editPost();
      case CommunityMoreAction.delete:
        if (await _vm.deletePost()) _finishRemoved();
      case CommunityMoreAction.block:
        await _blockAuthor(post.author?.memberId, popAfter: true);
      case CommunityMoreAction.report:
        await _report(CommunityReportTargetType.post, post.id);
    }
  }

  /// 댓글의 `⋯`.
  Future<void> _commentMore(CommunityRemoteComment comment) async {
    final action = await showCommunityMoreSheet(context, mine: comment.mine);
    if (!mounted || action == null) return;

    switch (action) {
      case CommunityMoreAction.edit:
        _startEditComment(comment);
      case CommunityMoreAction.delete:
        await _vm.deleteComment(comment.id);
      case CommunityMoreAction.block:
        await _blockAuthor(comment.author?.memberId, popAfter: false);
      case CommunityMoreAction.report:
        await _report(CommunityReportTargetType.comment, comment.id);
    }
  }

  Future<void> _report(CommunityReportTargetType type, int targetId) async {
    if (!_requireLogin()) return;
    final input = await showReportReasonSheet(context);
    if (!mounted || input == null) return;

    final ok = await _vm.report(
      targetType: type,
      targetId: targetId,
      reason: input.reason,
      detail: input.detail,
    );
    if (!ok || !mounted) return;
    _toast(AppLocalizations.of(context)!.communityReportDone);
  }

  Future<void> _blockAuthor(int? memberId, {required bool popAfter}) async {
    if (memberId == null || !_requireLogin()) return;
    final ok = await _vm.block(memberId);
    if (!ok || !mounted) return;
    _toast(AppLocalizations.of(context)!.communityBlockDone);
    if (popAfter) {
      _finishRemoved();
    } else {
      // 차단한 사람의 댓글은 서버가 BLOCKED 로 내려준다.
      await _vm.load();
    }
  }

  /// 신고·차단은 로그인해야 한다. 서버 401 을 그대로 보여주는 대신 로그인으로
  /// 보낸다.
  bool _requireLogin() {
    if (_vm.loggedIn) return true;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
    return false;
  }

  void _finishRemoved() {
    _removed = true;
    _pop();
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

    // 뒤로 갈 때 목록이 추천·댓글 수를 반영해야 해서 pop 결과를 실어 보내야
    // 하지만, 그렇다고 PopScope(canPop:false) 로 시스템 pop 자체를 막으면
    // iOS 엣지 스와이프 제스처가 통째로 죽는다(제스처가 시작은 되지만 놓는
    // 순간 canPop 이 거부해 항상 원위치로 튕김). 그래서 시스템 pop(스와이프·
    // Android 뒤로가기)은 막지 않고 그냥 흘려보낸다 — 결과 없이(null) pop 되면
    // 호출부([community_screen.dart]._openPost)가 그냥 목록을 갱신 안 하고
    // 넘어가도록 이미 null 을 허용해 둬서 안전하다. 결과를 반드시 실어야 하는
    // 경로(헤더의 뒤로가기 버튼)만 [_pop] 을 직접 호출한다.
    return Scaffold(
      backgroundColor: AppColors.narDark800,
      // 키보드가 올라온 상태에서 아무 데나 누르면 내려간다. translucent 라
      // 목록 항목·버튼의 탭은 그대로 각자에게 간다.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => Column(
              children: [
                NarDetailHeader(
                  title: _boardName(l),
                  scale: scale,
                  onBack: _pop,
                  trailing: _vm.post == null
                      ? null
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _postMore,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8 * scale,
                            ),
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
                Expanded(child: _content(l, scale)),
                if (_vm.post != null) _inputBar(l, scale),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 헤더에는 팀 **코드**를 쓴다. 가운데 슬롯이 좌우 아이콘 사이로 좁은데
  /// 팀 이름은 'Hanwha Life Esports' 처럼 길어서 그대로 넣으면 잘린다.
  /// 어느 게시판인지 알아보는 데는 코드로 충분하다(목록·칩은 전체 이름).
  String _boardName(AppLocalizations l) {
    final post = _vm.post;
    if (post == null) return l.communityTitle;
    if (post.boardTeamId == null) return l.communityBoardAll;
    final label = communityTeamLabel(post.boardTeamId);
    return label.isEmpty ? l.communityTitle : l.communityBoardTeam(label);
  }

  Widget _content(AppLocalizations l, double scale) {
    if (_vm.loading && _vm.post == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.narText2,
          ),
        ),
      );
    }
    final post = _vm.post;
    if (post == null) {
      return Center(
        child: Text(
          l.communityLoadFailed,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14 * scale,
            color: AppColors.narText2,
          ),
        ),
      );
    }

    final roots = _vm.rootComments;

    return ListView(
      controller: _scrollController,
      // 목록을 끌어내려도 키보드가 닫힌다.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: 24 * scale),
      children: [
        _body(l, scale, post),
        _actions(l, scale, post),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20 * scale,
            14 * scale,
            20 * scale,
            2 * scale,
          ),
          child: Text(
            l.communityCommentCount(post.commentCount),
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
        if (_vm.hasMoreComments)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12 * scale),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _vm.loadMoreComments,
              child: Center(
                child: Text(
                  l.communityMoreComments,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * scale,
                    height: 1.45,
                    color: AppColors.narViolet3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 최상위 댓글 + (펼쳤을 때) 그 답글들.
  List<Widget> _thread(CommunityRemoteComment root, double scale) {
    final replies = _vm.repliesTo(root.id);
    final expanded = _expanded.contains(root.id);

    return [
      CommentTile(
        comment: root,
        scale: scale,
        isReply: false,
        onLike: () => _vm.toggleCommentLike(root.id),
        onReply: () => _startReply(root),
        onMore: () => _commentMore(root),
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
              onLike: () => _vm.toggleCommentLike(reply.id),
              onReply: () => _startReply(reply),
              onMore: () => _commentMore(reply),
            ),
      ],
    ];
  }

  Widget _body(
    AppLocalizations l,
    double scale,
    CommunityRemotePostDetail post,
  ) {
    // 차단한 사용자의 글은 서버가 제목·본문·이미지를 비워서 내려준다.
    final blocked = post.viewer.blockedAuthor;

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
              ProfileAvatar(
                url: post.author?.profileImageUrl,
                size: 34 * scale,
              ),
              SizedBox(width: 9 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthorLine(
                      author: post.author,
                      scale: scale,
                      fontSize: 13,
                      logoSize: 14,
                      color: AppColors.narText,
                    ),
                    Text(
                      '${ratingTimeAgo(post.createdAt)} · '
                      '${l.communityViewCount(post.viewCount)}'
                      '${post.edited ? ' · ${l.communityEdited}' : ''}',
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
          if (blocked)
            Text(
              l.communityBlockedPost,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.65,
                color: AppColors.narText2,
              ),
            )
          else ...[
            Text(
              post.title,
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
              post.body,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                fontSize: 14 * scale,
                height: 1.65,
                color: AppColors.narText3,
              ),
            ),
            if (post.images.isNotEmpty) ...[
              SizedBox(height: 14 * scale),
              // 사진은 세로로 쌓는다. 캐러셀은 몇 장인지 안 보여서 첨부 수가
              // 적은 커뮤니티 글에는 스크롤로 지나가는 편이 낫다.
              for (var i = 0; i < post.images.length; i++) ...[
                if (i > 0) SizedBox(height: 8 * scale),
                // 높이를 고정하면(옛 200) 세로 사진이 위아래로 잘린다. 사진 자체가
                // 콘텐츠인 자리라 원본 비율을 지키고, 세로로 긴 사진만 화면 높이의
                // 70% 에서 끊는다 — 한 장이 화면을 통째로 먹으면 본문·댓글이 안 보인다.
                // 상한에 걸려 잘린 사진은 탭해서 전체화면으로 본다.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => CommunityPhotoViewer.open(
                    context,
                    urls: [for (final img in post.images) img.url],
                    initialIndex: i,
                  ),
                  child: CommunityImage(
                    source: post.images[i].url,
                    width: double.infinity,
                    height: null,
                    maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                    radius: 10 * scale,
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  /// 추천·댓글·스크랩을 폭 3등분으로 꽉 채운다. 칩으로 왼쪽에 몰아두면 본문과
  /// 댓글 사이의 경계가 흐려지는데, 균등 분할하면 그 자체가 구분선 역할을 한다.
  Widget _actions(
    AppLocalizations l,
    double scale,
    CommunityRemotePostDetail post,
  ) {
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
            asset: post.viewer.liked
                ? 'assets/icons/thumb-up-filled.svg'
                : 'assets/icons/thumb-up.svg',
            label: post.likeCount == 0
                ? l.communityLike
                : '${l.communityLike} ${post.likeCount}',
            active: post.viewer.liked,
            scale: scale,
            onTap: () {
              if (_requireLogin()) _vm.toggleLike();
            },
          ),
          _ActionCell(
            asset: 'assets/icons/message-circle.svg',
            label: l.communityCommentCount(post.commentCount),
            active: false,
            scale: scale,
            onTap: _focusComment,
          ),
          _ActionCell(
            asset: 'assets/icons/bookmark.svg',
            label: l.communityScrap,
            active: post.viewer.scrapped,
            scale: scale,
            onTap: () {
              if (_requireLogin()) _vm.toggleScrap();
            },
          ),
        ],
      ),
    );
  }

  /// 댓글 입력 바. 키보드가 올라오면 Scaffold 가 본문을 줄여 이 바를 그
  /// 위로 밀어 올린다(`resizeToAvoidBottomInset` 기본값).
  Widget _inputBar(AppLocalizations l, double scale) {
    final locked = !_vm.canWrite;
    final ready = _comment.text.trim().isNotEmpty && !_vm.submitting;
    final replyTo = _replyTo;
    final board = communityTeamLabel(_vm.post?.boardTeamId);

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 댓글 수정 중이면 입력창 위에 표시한다 — 안 그러면 새 댓글을 쓰는지
          // 고치는 중인지 화면에 안 남는다. X 로 수정 취소(입력 내용도 버린다).
          if (_editingComment != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.communityEditingComment,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5 * scale,
                        height: 1.45,
                        color: AppColors.narViolet3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cancelEditComment,
                    child: Icon(
                      Icons.close,
                      size: 15 * scale,
                      color: AppColors.narText2,
                    ),
                  ),
                ],
              ),
            ),
          // 답글 대상이 있으면 입력창 위에 누구에게 다는지 띄운다. 안 그러면
          // 답글 버튼을 눌렀는지 아닌지가 화면에 안 남는다.
          if (replyTo != null)
            Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.communityReplyingTo(
                        replyTo.author?.nickname ?? l.communityDeletedAuthor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5 * scale,
                        height: 1.45,
                        color: AppColors.narViolet3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _replyTo = null),
                    child: Icon(
                      Icons.close,
                      size: 15 * scale,
                      color: AppColors.narText2,
                    ),
                  ),
                ],
              ),
            ),
          Row(
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
                          ? (board.isEmpty
                                ? l.communityGuestWrite
                                : l.communityCommentLocked(board))
                          : l.communityCommentHint,
                      hintStyle: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                        fontSize: 13 * scale,
                        height: 1.45,
                        color: locked
                            ? AppColors.narDark300
                            : AppColors.narText2,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 10 * scale,
                      ),
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
                      color: ready
                          ? AppColors.narViolet3
                          : AppColors.narDark300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
