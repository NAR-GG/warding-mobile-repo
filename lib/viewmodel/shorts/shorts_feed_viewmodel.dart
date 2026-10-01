import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../model/story_video.dart';
import '../../repository/shorts/shorts_repository.dart';

/// 전체화면 쇼츠 피드 필터. 홈 쇼츠 탭과 같다.
enum ShortsFeedFilter { all, team }

/// 전체화면 세로 쇼츠 피드 상태.
///
/// 홈이 이미 받아 둔 영상으로 시작해 탭한 영상부터 보이고, 끝에 가까워지면
/// 다음 페이지를 이어 받는다. 재생(WebView)은 View 가 맡고, 여기서는 목록·
/// 필터·연속 실패만 다룬다. 페이지 이동은 View 가 등록하는 [onJumpTo] 로 위임한다.
class ShortsFeedViewModel extends ChangeNotifier {
  ShortsFeedViewModel({
    required List<StoryVideo> initialVideos,
    required Future<String?> Function() resolveTeamCode,
    int startIndex = 0,
    ShortsFeedFilter filter = ShortsFeedFilter.all,
    int initialPageSize = defaultPageSize,
    ShortsRepository? repository,
  }) : _videos = List.of(initialVideos),
       _index = startIndex.clamp(
         0,
         initialVideos.isEmpty ? 0 : initialVideos.length - 1,
       ),
       _filter = filter,
       _pageSize = initialPageSize,
       _resolveTeamCode = resolveTeamCode,
       _repo = repository ?? ShortsRepository.instance {
    // 홈은 0페이지를 받아 왔다 — 이어서 1페이지부터.
    _nextPage = 1;
    if (_videos.isEmpty) {
      unawaited(_reload());
    } else if (_index >= _videos.length - prefetchThreshold) {
      // 끝 근처에서 열었으면 스와이프 전에 미리 이어 받는다.
      unawaited(_loadMore());
    }
  }

  /// 필터를 바꿔 새로 받을 때 한 번에 받는 개수(문서 §6: 피드는 20개씩).
  static const int defaultPageSize = 20;

  /// 끝에서 이만큼 남으면 다음 페이지를 미리 요청한다.
  static const int prefetchThreshold = 3;

  /// 연속 이만큼 실패하면 스킵을 멈추고 "재생할 수 없어요"를 보인다.
  static const int maxConsecutiveErrors = 3;

  final ShortsRepository _repo;
  final Future<String?> Function() _resolveTeamCode;

  List<StoryVideo> _videos;
  List<StoryVideo> get videos => _videos;

  int _index;
  int get index => _index;

  ShortsFeedFilter _filter;
  ShortsFeedFilter get filter => _filter;

  int _pageSize;
  int _nextPage = 1;
  String? _teamCode;
  bool _isLast = false;
  bool _loading = false;
  int _gen = 0;
  bool _disposed = false;

  /// "내 팀"을 골랐는데 응원팀이 없다.
  bool _teamUnset = false;
  bool get teamUnset => _teamUnset;

  /// 처음 받는 중(목록이 비어 있음).
  bool get isLoading => _loading && _videos.isEmpty;

  /// 더 볼 영상이 없다 — 맨 끝에 "다 봤어요"를 붙인다.
  bool get isEnd => _isLast && !_loading;

  /// 페이지 수: 영상 + (끝이면) 끝 화면 한 장.
  int get pageCount => _videos.length + (isEnd && _videos.isNotEmpty ? 1 : 0);

  int _errors = 0;

  /// 연속 임베드 실패 수가 한계에 닿았다.
  bool get unavailable => _errors >= maxConsecutiveErrors;

  bool _pendingSkip = false;

  /// View 가 등록하는 페이지 이동. 화면 전환은 View 몫이라 콜백으로 둔다.
  void Function(int page)? onJumpTo;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 페이지가 바뀌었다.
  void onPageChanged(int page) {
    if (page == _index) return;
    _index = page;
    _notify();
    if (page >= _videos.length - prefetchThreshold) unawaited(_loadMore());
  }

  /// 현재 영상이 재생되기 시작했다 — 연속 실패를 끊는다.
  void reportPlaying(int page) {
    if (page != _index || _errors == 0) return;
    _errors = 0;
    _notify();
  }

  /// [page] 영상이 끝났다 — 현재 영상이면 다음으로 넘긴다.
  void reportEnded(int page) {
    if (page != _index) return;
    _skipToNext();
  }

  /// [page] 영상의 임베드가 실패했다(삭제·비공개·임베드 불가 등). 현재 영상이면
  /// 다음으로 자동 스킵하고, 연속 [maxConsecutiveErrors] 건이면 멈춘다.
  void reportError(int page, {Object? code}) {
    if (page != _index) return;
    debugPrint(
      '[Shorts] 임베드 오류 page=$page code=$code '
      'id=${_videos[page].youtubeVideoId}',
    );
    _errors++;
    _notify();
    if (unavailable) return;
    _skipToNext();
  }

  void _skipToNext() {
    final next = _index + 1;
    if (next < pageCount) {
      onJumpTo?.call(next);
    } else if (!_isLast) {
      // 다음 페이지가 아직 안 왔다 — 받은 뒤에 넘어간다.
      _pendingSkip = true;
      unawaited(_loadMore());
    }
  }

  /// 오류 상태를 풀고 현재 영상부터 다시 시도한다("재생할 수 없어요" 화면의 재시도).
  void retry() {
    _errors = 0;
    _notify();
  }

  Future<void> setFilter(ShortsFeedFilter next) async {
    if (next == _filter) return;
    _filter = next;
    await _reload();
  }

  Future<void> _reload() async {
    final gen = ++_gen;
    _videos = const [];
    _index = 0;
    _nextPage = 0;
    _pageSize = defaultPageSize;
    _isLast = false;
    _errors = 0;
    _teamUnset = false;
    _pendingSkip = false;
    _teamCode = null;
    _loading = true;
    _notify();

    if (_filter == ShortsFeedFilter.team) {
      String? code;
      try {
        code = await _resolveTeamCode();
      } catch (e) {
        debugPrint('[Shorts] 응원팀 조회 실패: $e');
      }
      if (_disposed || gen != _gen) return;
      if (code == null || code.isEmpty) {
        _teamUnset = true;
        _loading = false;
        _isLast = true;
        _notify();
        return;
      }
      _teamCode = code;
    }
    await _fetch(gen);
  }

  Future<void> _loadMore() async {
    if (_loading || _isLast) return;
    _loading = true;
    _notify();
    await _fetch(_gen);
  }

  Future<void> _fetch(int gen) async {
    _loading = true;
    var ok = false;
    try {
      final page = await _repo.fetchShortsPage(
        page: _nextPage,
        size: _pageSize,
        teamCode: _teamCode,
      );
      if (_disposed || gen != _gen) return;
      _nextPage++;
      _isLast = page.isLast;
      final seen = {for (final v in _videos) v.videoId};
      final code = _teamCode;
      _videos = [
        ..._videos,
        for (final v in page.items)
          if (!seen.contains(v.videoId) && (code == null || v.teamCode == code))
            v,
      ];
      ok = true;
    } catch (e) {
      // 네트워크 실패: 현재 영상은 그대로 두고 다음 스와이프 때 다시 요청한다.
      debugPrint('[Shorts] 다음 페이지 조회 실패: $e');
      _pendingSkip = false;
    } finally {
      if (!_disposed && gen == _gen) {
        _loading = false;
        _notify();
      }
    }
    if (_disposed || gen != _gen) return;
    // 서버가 팀을 안 거르는 동안 한 페이지가 전부 걸러질 수 있다 — 이어 받는다.
    if (ok && _videos.isEmpty && !_isLast) {
      await _loadMore();
      return;
    }
    if (_pendingSkip) {
      _pendingSkip = false;
      final next = _index + 1;
      if (next < pageCount) onJumpTo?.call(next);
    }
  }
}
