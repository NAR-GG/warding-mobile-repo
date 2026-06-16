import 'package:flutter/foundation.dart';

import '../../model/my_rating_list.dart';
import '../../repository/rating/rating_repository.dart';

/// 마이페이지 '내 리뷰/평점' 상태·로직.
///
/// `me/ratings` 를 페이지네이션으로 로드하고, 작성일(createdAt) 기준
/// 'YYYY.MM.DD' 로 그룹핑한다. 삭제 시 목록과 누적 건수를 갱신한다.
class MyReviewViewModel extends ChangeNotifier {
  MyReviewViewModel({RatingRepository? repository})
      : _repository = repository ?? RatingRepository.instance;

  final RatingRepository _repository;

  final List<MyRatingItem> _items = [];
  List<MyRatingItem> get items => List.unmodifiable(_items);

  int _page = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  int get totalElements => _totalElements;

  bool _loading = false;
  bool get loading => _loading;
  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;
  String? _error;
  String? get error => _error;

  bool get hasMore => _page + 1 < _totalPages;

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// 작성일 기준 'YYYY.MM.DD' → 항목들. 삽입 순서(최신 우선)를 유지한다.
  Map<String, List<MyRatingItem>> get grouped {
    final map = <String, List<MyRatingItem>>{};
    for (final item in _items) {
      final c = item.createdAt;
      final key = c == null
          ? '-'
          : '${c.year}.${c.month.toString().padLeft(2, '0')}.'
              '${c.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final result = await _repository.fetchMyRatings(page: 0);
      _items
        ..clear()
        ..addAll(result.ratings);
      _page = result.page;
      _totalPages = result.totalPages;
      _totalElements = result.totalElements;
    } catch (e) {
      debugPrint('[MyReviewVM] load failed: $e');
      _error = '내 평가를 불러오지 못했어요';
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  Future<void> loadMore() async {
    if (!hasMore || _loadingMore) return;
    _loadingMore = true;
    _safeNotify();
    try {
      final result = await _repository.fetchMyRatings(page: _page + 1);
      _items.addAll(result.ratings);
      _page = result.page;
      _totalPages = result.totalPages;
      _totalElements = result.totalElements;
    } catch (e) {
      debugPrint('[MyReviewVM] loadMore failed: $e');
    } finally {
      _loadingMore = false;
      _safeNotify();
    }
  }

  /// 평가 삭제. 성공 시 목록에서 제거하고 누적 건수를 1 줄인다.
  Future<void> deleteRating(MyRatingItem item) async {
    try {
      await _repository.deleteMyRating(item.gameId, item.participantId);
    } catch (e) {
      debugPrint('[MyReviewVM] delete failed: $e');
      rethrow;
    }
    _items.removeWhere((e) => e.ratingId == item.ratingId);
    if (_totalElements > 0) _totalElements--;
    _safeNotify();
  }
}
