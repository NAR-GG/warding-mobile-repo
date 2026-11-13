import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/features/community/data/community_repository.dart';
import 'package:warding/features/community/domain/community_remote_post.dart';

/// 커뮤니티 글 요약 목록의 정렬 기준.
///
/// [hot] 은 칩에서 뺀 상태다([CommunitySummaryViewModel.availableSorts]) —
/// 글이 적을 때 늘 같은 글이 보여서다(spec 결정). 로직은 남겨 둔다.
enum CommunitySummarySort { latest, hot }

/// 다른 화면에 끼워 넣는 커뮤니티 글 요약 섹션의 상태.
///
/// 전체 목록 화면은 [CommunityListViewModel] 이다 — 그쪽은 팀 게시판 필터와
/// 무한 스크롤(cursor 페이지네이션)을 하고, 이쪽은 최신 몇 건만 보여준다.
/// 요청 모양이 달라 한 ViewModel 로 합치지 않았다.
///
/// 홈 화면이 쓰지만 홈에 종속되지 않는다 — 커뮤니티 요약이 필요한 화면은
/// 어디서든 이것을 구독하면 된다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다 —
/// 홈처럼 여러 섹션을 한 번에 당기는 화면이 자기 갱신 주기에 맞춰야 한다.
class CommunitySummaryViewModel extends ChangeNotifier {
  CommunitySummaryViewModel({
    CommunityRepository? repository,
    this.postCount = 4,
  }) : _repository = repository ?? CommunityRepository.instance;

  final CommunityRepository _repository;

  /// 보여줄 글 수.
  final int postCount;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  CommunitySummarySort _sort = CommunitySummarySort.latest;
  CommunitySummarySort get sort => _sort;

  /// 보여줄 정렬 탭. 인기순은 커뮤니티가 활성화될 때까지 뺀다(글이 적어 의미가
  /// 없다).
  List<CommunitySummarySort> get availableSorts => const [
    CommunitySummarySort.latest,
  ];

  /// 정렬을 바꾼다. 그 기준으로 글을 다시 조회한다.
  void setSort(CommunitySummarySort value) {
    if (value == _sort) return;
    if (!availableSorts.contains(value)) return;
    _sort = value;
    notifyListeners();
    unawaited(load());
  }

  List<CommunityRemotePost> _posts = const [];

  /// 현재 정렬 기준의 글. 조회 실패 시 마지막 목록을 유지한다.
  List<CommunityRemotePost> get posts => _posts;

  /// 첫 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다.
  bool _firstLoadPending = true;
  bool get loading => _firstLoadPending;

  Future<void> load() async {
    final sort = _sort;
    try {
      final page = await _repository.fetchPosts(
        size: postCount,
        sort: sort.name,
      );
      // 응답이 오는 사이 정렬을 바꿨으면 버린다 — 바뀐 정렬이 다시 조회한다.
      if (_disposed || sort != _sort) return;
      _posts = page.posts;
      _firstLoadPending = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[CommunitySummary] 글 조회 실패(${sort.name}): $e');
      if (_disposed || sort != _sort) return;
      _firstLoadPending = false;
      notifyListeners();
    }
  }

  /// 게시글 상세에서 삭제하고 돌아왔을 때 요약 목록에서도 지운다.
  void removePost(int postId) {
    if (!_posts.any((p) => p.id == postId)) return;
    _posts = [
      for (final p in _posts)
        if (p.id != postId) p,
    ];
    notifyListeners();
  }

  /// 게시글 상세에서 좋아요·조회수 등이 바뀌고 돌아왔을 때 요약에도 반영한다.
  void applyPostUpdate(CommunityRemotePost updated) {
    final index = _posts.indexWhere((p) => p.id == updated.id);
    if (index == -1) return;
    _posts = [..._posts];
    _posts[index] = updated;
    notifyListeners();
  }
}
