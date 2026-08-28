import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import '../../model/community_remote_post.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/community/community_repository.dart';
import '../../screens/community/community_permission.dart';

/// 게시판 하나의 목록 상태. 커뮤니티 화면은 전체·우리팀·다른팀 셋을 동시에
/// 들고 있어서(스와이프로 왔다 갔다 한다) 게시판마다 이 상태를 따로 둔다.
/// 탭을 옮길 때마다 다시 받아오면 스크롤 위치도 목록도 매번 초기화된다.
class CommunityBoardState {
  final List<CommunityRemotePost> posts = [];

  /// 다음 페이지 커서. null 이면 마지막 페이지다.
  int? nextCursor;

  /// 한 번이라도 성공적으로 받아왔는가. 탭 재방문 시 재요청을 막는 기준.
  bool loaded = false;

  bool loading = false;
  bool loadingMore = false;
  String? error;

  /// 서버가 내려준 쓰기 권한. 팀 게시판 + 로그인일 때만 채워진다.
  CommunityBoardViewer? viewer;

  bool get hasMore => nextCursor != null;
}

/// 커뮤니티 목록 화면 상태·로직.
///
/// 쓰기 권한은 **서버 판정을 우선한다**([CommunityBoardViewer]). 앱은 "내
/// 응원팀인가"만 알지, 응원팀을 바꾼 지 30일이 지났는지(쿨다운)는 모른다.
/// 서버 판정이 아직 없을 때(전체 게시판·비로그인·로드 전)만 [canWriteToBoard]
/// 로 떨어진다.
class CommunityListViewModel extends ChangeNotifier {
  CommunityListViewModel({CommunityRepository? repository, AuthService? auth})
    : _repository = repository ?? CommunityRepository.instance,
      _auth = auth ?? AuthService.instance;

  final CommunityRepository _repository;
  final AuthService _auth;

  final Map<int?, CommunityBoardState> _boards = {};

  bool _sessionLoaded = false;
  bool get sessionLoaded => _sessionLoaded;

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  int? _myTeamId;
  int? get myTeamId => _myTeamId;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// [boardTeamId] 가 null 이면 전체 게시판.
  CommunityBoardState board(int? boardTeamId) =>
      _boards.putIfAbsent(boardTeamId, CommunityBoardState.new);

  Future<void> init() async {
    await loadSession();
    await load(null);
  }

  /// 로그인 여부와 응원팀을 다시 읽는다. 로그인 화면이나 프로필 수정에서
  /// 돌아왔을 때 호출한다 — 응원팀이 바뀌면 '우리팀' 탭 자체가 달라진다.
  Future<void> loadSession() async {
    final before = _myTeamId;
    try {
      final token = await _auth.jwt;
      _loggedIn = token != null && token.isNotEmpty;
      _myTeamId = _loggedIn ? (await _auth.fetchMe()).favoriteTeamId : null;
    } catch (e) {
      // 세션을 못 읽어도 목록은 읽힌다. 쓰기만 잠긴 상태로 둔다.
      debugPrint('[CommunityListVM] session failed: $e');
    }
    // 응원팀이 바뀌었으면 옛 팀 게시판 캐시는 남겨둬도 의미가 없다.
    if (before != _myTeamId) _boards.remove(before);
    _sessionLoaded = true;
    _safeNotify();
  }

  /// 게시판 첫 로드. 이미 받아온 게시판은 [refresh] 일 때만 다시 받는다.
  Future<void> load(int? boardTeamId, {bool refresh = false}) async {
    final state = board(boardTeamId);
    if (state.loading) return;
    if (state.loaded && !refresh) return;

    state.loading = true;
    state.error = null;
    _safeNotify();
    try {
      final page = await _repository.fetchPosts(boardTeamId: boardTeamId);
      state.posts
        ..clear()
        ..addAll(page.posts);
      state.nextCursor = page.nextCursor;
      state.viewer = page.boardViewer;
      state.loaded = true;
    } catch (e) {
      debugPrint('[CommunityListVM] load($boardTeamId) failed: $e');
      state.error = appStrings?.communityLoadFailed ?? 'Failed to load posts';
    } finally {
      state.loading = false;
      _safeNotify();
    }
  }

  /// 커서 다음 페이지. 실패하면 조용히 끝낸다 — 이미 보고 있는 목록은
  /// 그대로 남아 있어서 에러 화면으로 덮을 이유가 없다.
  Future<void> loadMore(int? boardTeamId) async {
    final state = board(boardTeamId);
    if (state.loadingMore || state.loading || !state.hasMore) return;

    state.loadingMore = true;
    _safeNotify();
    try {
      final page = await _repository.fetchPosts(
        boardTeamId: boardTeamId,
        cursor: state.nextCursor,
      );
      state.posts.addAll(page.posts);
      state.nextCursor = page.nextCursor;
    } catch (e) {
      debugPrint('[CommunityListVM] loadMore($boardTeamId) failed: $e');
    } finally {
      state.loadingMore = false;
      _safeNotify();
    }
  }

  /// 상세에서 돌아왔을 때 그 글의 추천·댓글 수만 갱신한다. 목록 전체를 다시
  /// 받으면 스크롤이 맨 위로 튄다.
  void applyPostUpdate(int? boardTeamId, CommunityRemotePost updated) {
    final posts = board(boardTeamId).posts;
    final index = posts.indexWhere((p) => p.id == updated.id);
    if (index < 0) return;
    posts[index] = updated;
    _safeNotify();
  }

  /// 삭제된 글을 목록에서 뺀다.
  void removePost(int? boardTeamId, int postId) {
    board(boardTeamId).posts.removeWhere((p) => p.id == postId);
    _safeNotify();
  }

  bool canWrite(int? boardTeamId) {
    final viewer = board(boardTeamId).viewer;
    if (viewer != null) return viewer.canWrite;
    return canWriteToBoard(
      loggedIn: _loggedIn,
      myTeamId: _myTeamId,
      boardTeamId: boardTeamId,
    );
  }

  /// 쓰기가 막힌 이유. 서버가 안 알려준 경우(전체 게시판·비로그인)는 null 이고,
  /// 화면이 로그인·응원팀 미설정 문구로 직접 분기한다.
  CommunityWriteLockReason? lockReason(int? boardTeamId) =>
      board(boardTeamId).viewer?.reason;

  /// 쿨다운이 풀리는 시각([CommunityWriteLockReason.cooldown] 일 때만).
  DateTime? writableFrom(int? boardTeamId) =>
      board(boardTeamId).viewer?.writableFrom;
}
