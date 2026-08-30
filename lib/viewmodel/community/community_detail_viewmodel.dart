import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import '../../model/community_remote_comment.dart';
import '../../model/community_remote_post.dart';
import '../../model/community_report.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/community/community_api_exception.dart';
import '../../repository/community/community_report_repository.dart';
import '../../repository/community/community_repository.dart';
import '../../screens/community/community_permission.dart';

/// 글 상세 상태·로직 — 본문 · 추천/스크랩 · 댓글(1단 답글) · 신고/차단/삭제.
class CommunityDetailViewModel extends ChangeNotifier {
  CommunityDetailViewModel({
    required this.postId,
    CommunityRepository? repository,
    CommunityReportRepository? reportRepository,
    AuthService? auth,
  }) : _repository = repository ?? CommunityRepository.instance,
       _reports = reportRepository ?? CommunityReportRepository.instance,
       _auth = auth ?? AuthService.instance;

  final int postId;
  final CommunityRepository _repository;
  final CommunityReportRepository _reports;
  final AuthService _auth;

  CommunityRemotePostDetail? _post;
  CommunityRemotePostDetail? get post => _post;

  final List<CommunityRemoteComment> _comments = [];
  List<CommunityRemoteComment> get comments => List.unmodifiable(_comments);

  int? _commentCursor;
  bool get hasMoreComments => _commentCursor != null;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMoreComments = false;
  bool get loadingMoreComments => _loadingMoreComments;

  bool _submitting = false;
  bool get submitting => _submitting;

  String? _error;
  String? get error => _error;

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  int? _myTeamId;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// 최상위 댓글(작성 순).
  List<CommunityRemoteComment> get rootComments =>
      _comments.where((c) => c.parentId == null).toList();

  /// [rootId] 에 달린 답글. 답글의 답글도 여기로 평평하게 들어온다 —
  /// 서버가 parentId 를 항상 최상위 댓글로 올려붙인다.
  List<CommunityRemoteComment> repliesTo(int rootId) =>
      _comments.where((c) => c.parentId == rootId).toList();

  /// 이 글의 게시판에 댓글을 쓸 수 있는가.
  ///
  /// 목록과 달리 상세 응답에는 서버 판정이 없어 로컬 규칙으로만 본다. 응원팀
  /// 쿨다운처럼 앱이 모르는 사유는 여기서 못 걸러지고, 실제로 보낼 때 서버가
  /// 403 으로 막으며 그 메시지를 [error] 로 띄운다.
  bool get canWrite => canWriteToBoard(
    loggedIn: _loggedIn,
    myTeamId: _myTeamId,
    boardTeamId: _post?.boardTeamId,
  );

  /// [countView] 는 최초 진입에만 true — 당겨서 새로고침이 조회수를 부풀리면 안 된다.
  Future<void> load({bool countView = true}) async {
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final token = await _auth.jwt;
      _loggedIn = token != null && token.isNotEmpty;
      if (_loggedIn) {
        try {
          _myTeamId = (await _auth.fetchMe()).favoriteTeamId;
        } catch (e) {
          debugPrint('[CommunityDetailVM] me failed: $e');
        }
      }
      _post = await _repository.fetchPostDetail(postId);
      await _loadComments();
      // 조회수는 집계 핑이라 결과를 기다리지 않는다.
      if (countView) unawaited(_repository.markPostViewed(postId));
    } catch (e) {
      debugPrint('[CommunityDetailVM] load failed: $e');
      _error = appStrings?.communityLoadFailed ?? 'Failed to load post';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> _loadComments() async {
    final page = await _repository.fetchComments(postId);
    _comments
      ..clear()
      ..addAll(page.comments);
    _commentCursor = page.nextCursor;
  }

  Future<void> loadMoreComments() async {
    if (_loadingMoreComments || !hasMoreComments) return;
    _loadingMoreComments = true;
    _safeNotify();
    try {
      final page = await _repository.fetchComments(
        postId,
        cursor: _commentCursor,
      );
      _comments.addAll(page.comments);
      _commentCursor = page.nextCursor;
    } catch (e) {
      debugPrint('[CommunityDetailVM] loadMoreComments failed: $e');
    } finally {
      _loadingMoreComments = false;
      _safeNotify();
    }
  }

  /// 추천 토글. 서버가 최종 상태와 개수를 돌려주므로 낙관적 갱신을 하지 않는다
  /// — 연타해도 서버 값으로 수렴한다.
  Future<void> toggleLike() async {
    final current = _post;
    if (current == null) return;
    try {
      final result = await _repository.toggleLike(postId);
      _post = _replaceSummary(
        current,
        liked: result.liked,
        likeCount: result.likeCount,
      );
      _safeNotify();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> toggleScrap() async {
    final current = _post;
    if (current == null) return;
    try {
      final scrapped = await _repository.toggleScrap(postId);
      _post = _replaceSummary(current, scrapped: scrapped);
      _safeNotify();
    } catch (e) {
      _fail(e);
    }
  }

  /// 이 글 알림 켬/끔. 반환 = 토글 후 수신 여부(토스트 문구용), 실패 시 null.
  Future<bool?> toggleNotification() async {
    final current = _post;
    if (current == null) return null;
    try {
      final enabled = await _repository.togglePostNotification(postId);
      _post = _replaceSummary(current, notificationEnabled: enabled);
      _safeNotify();
      return enabled;
    } catch (e) {
      _fail(e);
      return null;
    }
  }

  Future<void> toggleCommentLike(int commentId) async {
    try {
      final result = await _repository.toggleCommentLike(commentId);
      final index = _comments.indexWhere((c) => c.id == commentId);
      if (index < 0) return;
      final old = _comments[index];
      _comments[index] = CommunityRemoteComment(
        id: old.id,
        parentId: old.parentId,
        status: old.status,
        body: old.body,
        author: old.author,
        mentionNickname: old.mentionNickname,
        likeCount: result.likeCount,
        liked: result.liked,
        mine: old.mine,
        edited: old.edited,
        createdAt: old.createdAt,
      );
      _safeNotify();
    } catch (e) {
      _fail(e);
    }
  }

  /// 댓글·답글 작성. [replyToCommentId] 에는 대상 댓글 id 를 그대로 넘긴다 —
  /// 최상위로 올려붙이는 건 서버가 한다.
  Future<bool> submitComment(String body, {int? replyToCommentId}) async {
    final text = body.trim();
    if (text.isEmpty || _submitting) return false;
    _submitting = true;
    _error = null;
    _safeNotify();
    try {
      await _repository.createComment(
        postId,
        body: text,
        replyToCommentId: replyToCommentId,
      );
      // 새 댓글이 어느 스레드 어디에 꽂히는지는 서버가 정하므로 다시 받는다.
      await _loadComments();
      final current = _post;
      if (current != null) {
        _post = _replaceSummary(
          current,
          commentCount: current.commentCount + 1,
        );
      }
      return true;
    } catch (e) {
      _fail(e);
      return false;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  /// 댓글 본문 수정. 수정 결과(edited 포함)는 서버가 정하므로 다시 받는다.
  Future<bool> updateComment(int commentId, String body) async {
    final text = body.trim();
    if (text.isEmpty || _submitting) return false;
    _submitting = true;
    _error = null;
    _safeNotify();
    try {
      await _repository.updateComment(commentId, body: text);
      await _loadComments();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  Future<bool> deleteComment(int commentId) async {
    try {
      await _repository.deleteComment(commentId);
      await _loadComments();
      _safeNotify();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> deletePost() async {
    try {
      await _repository.deletePost(postId);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> report({
    required CommunityReportTargetType targetType,
    required int targetId,
    required CommunityReportReason reason,
    String? detail,
  }) async {
    try {
      await _reports.report(
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        detail: detail,
      );
      return true;
    } on CommunityApiException catch (e) {
      // 같은 대상 재신고는 409. 이미 접수된 것이니 실패로 보여줄 이유가 없다.
      if (e.statusCode == 409) return true;
      _fail(e);
      return false;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> block(int memberId) async {
    try {
      await _reports.block(memberId);
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _safeNotify();
  }

  void _fail(Object e) {
    debugPrint('[CommunityDetailVM] $e');
    _error = e is CommunityApiException
        ? e.message
        : (appStrings?.communityActionFailed ?? 'Request failed');
    _safeNotify();
  }

  /// 상세 응답의 요약부만 갈아끼운다. 목록으로 돌아갈 때 이 요약을 그대로
  /// 넘겨 추천·댓글 수를 반영한다.
  CommunityRemotePostDetail _replaceSummary(
    CommunityRemotePostDetail current, {
    int? likeCount,
    int? commentCount,
    bool? liked,
    bool? scrapped,
    bool? notificationEnabled,
  }) {
    final s = current.summary;
    return CommunityRemotePostDetail(
      summary: CommunityRemotePost(
        id: s.id,
        boardTeamId: s.boardTeamId,
        title: s.title,
        bodyPreview: s.bodyPreview,
        author: s.author,
        viewCount: s.viewCount,
        likeCount: likeCount ?? s.likeCount,
        commentCount: commentCount ?? s.commentCount,
        edited: s.edited,
        createdAt: s.createdAt,
        thumbnailUrl: s.thumbnailUrl,
        imageCount: s.imageCount,
      ),
      body: current.body,
      images: current.images,
      viewer: CommunityPostViewer(
        liked: liked ?? current.viewer.liked,
        scrapped: scrapped ?? current.viewer.scrapped,
        mine: current.viewer.mine,
        blockedAuthor: current.viewer.blockedAuthor,
        notificationEnabled:
            notificationEnabled ?? current.viewer.notificationEnabled,
      ),
    );
  }
}
