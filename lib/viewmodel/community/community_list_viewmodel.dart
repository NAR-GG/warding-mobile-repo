import 'dart:async';

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
/// 쓰기 권한은 **서버 판정을 우선한다**([CommunityBoardViewer]) — API 를 직접
/// 부르는 경로까지 막는 최종 판정이 서버에 있고, 사유가 늘어도 앱을 안 고친다.
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

  /// 작성 간격 카운트다운을 1초마다 다시 그리게 하는 타이머. 남은 게시판이
  /// 없으면 멈춘다 — 아무도 안 기다리는데 초당 리빌드를 돌릴 이유가 없다.
  Timer? _tick;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
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
      _syncTick();
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

  /// 상세에서 돌아왔을 때 그 글의 수치만 갱신한다. 목록 전체를 다시 받으면
  /// 스크롤이 맨 위로 튄다.
  ///
  /// **행을 통째로 바꾸지 않는다.** 상세 응답(`PostDetailResponse`)에는 목록
  /// 전용 필드인 `bodyPreview`·`thumbnailUrl`·`imageCount` 가 없어서, 상세에서
  /// 만든 요약으로 덮으면 글을 한 번 열었다 나온 순간 본문 미리보기와 썸네일이
  /// 사라진다. 상세가 실제로 아는 값만 덮어쓴다.
  void applyPostUpdate(int? boardTeamId, CommunityRemotePost updated) {
    final posts = board(boardTeamId).posts;
    final index = posts.indexWhere((p) => p.id == updated.id);
    if (index < 0) return;
    final old = posts[index];
    posts[index] = CommunityRemotePost(
      id: old.id,
      boardTeamId: old.boardTeamId,
      // 재조립에서 옵셔널 필드를 빼먹으면 조용히 null 로 리셋된다 —
      // bodyFormat 실사고(#258)와 같은 함정. 배지 켜진 목록에서 글을
      // 열었다 나오면 그 줄의 팀 배지만 사라지는 형태로 발현한다.
      boardTeamCode: old.boardTeamCode,
      title: updated.title.isEmpty ? old.title : updated.title,
      bodyPreview: old.bodyPreview,
      author: updated.author ?? old.author,
      viewCount: updated.viewCount,
      likeCount: updated.likeCount,
      commentCount: updated.commentCount,
      edited: updated.edited,
      createdAt: old.createdAt,
      thumbnailUrl: old.thumbnailUrl,
      imageCount: old.imageCount,
      hasPoll: old.hasPoll,
    );
    _safeNotify();
  }

  /// 삭제된 글을 목록에서 뺀다.
  void removePost(int? boardTeamId, int postId) {
    board(boardTeamId).posts.removeWhere((p) => p.id == postId);
    _safeNotify();
  }

  /// 이 게시판에 다시 쓸 수 있을 때까지 남은 초. 0 이면 지금 쓸 수 있다.
  ///
  /// 서버가 게시판별로 재서 목록 응답에 실어 준다(작성 간격 D-9). 앱이 직접
  /// 세지 않는 이유는 간격 값이 서버 설정이고, 다른 기기에서 쓴 것도 잡혀야
  /// 하기 때문이다.
  int writeCooldownSeconds(int? boardTeamId) {
    final until = board(boardTeamId).viewer?.nextWritableAt;
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining + 1 : 0;
  }

  /// 카운트다운이 남은 게시판이 하나라도 있으면 초당 통지, 없으면 타이머를 끈다.
  void _syncTick() {
    final waiting = _boards.keys.any((id) => writeCooldownSeconds(id) > 0);
    if (waiting) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _safeNotify();
        _syncTick();
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
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

  /// 테스트 글을 만들 수 있는 계정인가(서버 판정). 작성 화면 토글 노출용.
  bool isTester(int? boardTeamId) => board(boardTeamId).viewer?.tester ?? false;
}
