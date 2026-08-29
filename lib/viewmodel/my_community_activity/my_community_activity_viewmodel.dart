import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import '../../model/community_my_activity.dart';
import '../../model/community_remote_post.dart';
import '../../repository/community/community_activity_repository.dart';

/// 목록 한 종류의 로딩 상태 — 내가 쓴 글·내가 쓴 댓글·스크랩이 각자 하나씩 든다.
///
/// 커서 페이지네이션이라 총 건수가 없다([hasMore]만 안다).
class MyActivityListState<T> {
  final List<T> items = [];

  /// 다음 페이지 커서. null 이면 마지막 페이지다.
  int? nextCursor;

  /// 한 번이라도 성공적으로 받아왔는가. 탭 재방문 시 재요청을 막는 기준.
  bool loaded = false;

  bool loading = false;
  bool loadingMore = false;
  String? error;

  bool get hasMore => nextCursor != null;
}

/// 마이페이지 "내 활동"(내가 쓴 글·내가 쓴 댓글·스크랩) 상태·로직.
///
/// 세 목록은 항목 타입도 커서 의미도 달라(글 id / 댓글 id / scrapId) 각자
/// 독립된 [MyActivityListState] 를 갖는다. 탭마다 스크롤 위치가 따로 있어야
/// 하는 것과 같은 이유로, 로딩 상태도 섞이지 않는다.
class MyCommunityActivityViewModel extends ChangeNotifier {
  MyCommunityActivityViewModel({CommunityActivityRepository? repository})
    : _repository = repository ?? CommunityActivityRepository.instance;

  final CommunityActivityRepository _repository;

  final MyActivityListState<CommunityRemotePost> posts = MyActivityListState();
  final MyActivityListState<CommunityMyComment> comments =
      MyActivityListState();
  final MyActivityListState<CommunityScrapItem> scraps = MyActivityListState();

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// 첫 로드. 이미 받아왔으면 [refresh] 일 때만 다시 받는다.
  Future<void> _load<T>(
    MyActivityListState<T> state,
    Future<(List<T> items, int? nextCursor)> Function({int? cursor})
    fetchPage, {
    bool refresh = false,
  }) async {
    if (state.loading) return;
    if (state.loaded && !refresh) return;

    state.loading = true;
    state.error = null;
    _safeNotify();
    try {
      final (items, nextCursor) = await fetchPage();
      state.items
        ..clear()
        ..addAll(items);
      state.nextCursor = nextCursor;
      state.loaded = true;
    } catch (e) {
      debugPrint('[MyActivityVM] load failed: $e');
      state.error = appStrings?.communityLoadFailed ?? 'Failed to load posts';
    } finally {
      state.loading = false;
      _safeNotify();
    }
  }

  /// 커서 다음 페이지. 실패하면 조용히 끝낸다 — 이미 보고 있는 목록은
  /// 그대로 남아 있어서 에러 화면으로 덮을 이유가 없다.
  Future<void> _loadMore<T>(
    MyActivityListState<T> state,
    Future<(List<T> items, int? nextCursor)> Function({int? cursor}) fetchPage,
  ) async {
    if (state.loadingMore || state.loading || !state.hasMore) return;

    state.loadingMore = true;
    _safeNotify();
    try {
      final (items, nextCursor) = await fetchPage(cursor: state.nextCursor);
      state.items.addAll(items);
      state.nextCursor = nextCursor;
    } catch (e) {
      debugPrint('[MyActivityVM] loadMore failed: $e');
    } finally {
      state.loadingMore = false;
      _safeNotify();
    }
  }

  Future<void> loadPosts({bool refresh = false}) =>
      _load(posts, ({cursor}) async {
        final page = await _repository.fetchMyPosts(cursor: cursor);
        return (page.posts, page.nextCursor);
      }, refresh: refresh);

  Future<void> loadMorePosts() => _loadMore(posts, ({cursor}) async {
    final page = await _repository.fetchMyPosts(cursor: cursor);
    return (page.posts, page.nextCursor);
  });

  Future<void> loadComments({bool refresh = false}) =>
      _load(comments, ({cursor}) async {
        final page = await _repository.fetchMyComments(cursor: cursor);
        return (page.comments, page.nextCursor);
      }, refresh: refresh);

  Future<void> loadMoreComments() => _loadMore(comments, ({cursor}) async {
    final page = await _repository.fetchMyComments(cursor: cursor);
    return (page.comments, page.nextCursor);
  });

  Future<void> loadScraps({bool refresh = false}) =>
      _load(scraps, ({cursor}) async {
        final page = await _repository.fetchScraps(cursor: cursor);
        return (page.items, page.nextCursor);
      }, refresh: refresh);

  Future<void> loadMoreScraps() => _loadMore(scraps, ({cursor}) async {
    final page = await _repository.fetchScraps(cursor: cursor);
    return (page.items, page.nextCursor);
  });
}
