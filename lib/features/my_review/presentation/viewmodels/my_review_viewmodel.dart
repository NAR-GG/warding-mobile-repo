import 'package:flutter/foundation.dart';

import 'package:warding/core/domain/failure.dart';
import 'package:warding/core/di_container.dart';
import 'package:warding/features/my_review/domain/entities/my_review_item.dart';
import 'package:warding/features/my_review/domain/repositories/my_review_repository.dart';
import 'package:warding/features/my_review/presentation/models/my_review_ui_state.dart';

/// 마이페이지 '내 리뷰/평점' 상태.
///
/// "어떻게 보여줄까" 만 담당한다 — 페이지네이션 상태, 작성일 그룹핑, 실패를
/// 어떤 문구로 보일지.
///
/// repository 인터페이스를 직접 쓴다. UseCase 를 두지 않는 이유는 이 화면이
/// repository 하나만 쓰고 조합할 로직도 없어서다 — 그런 UseCase 는 파라미터만
/// 옮기는 통과 계층이 된다. 여러 repository 를 묶거나 규칙이 재사용될 때만
/// `domain/usecases/` 를 만든다.
///
/// 실패는 [Failure] 종류를 받아 여기서 문구로 바꾼다. repository 가 메시지를
/// 만들면 l10n 을 모르는 계층이 사용자 문구를 쥐게 된다.
class MyReviewViewModel extends ChangeNotifier {
  MyReviewViewModel({MyReviewRepository? repository})
      : _repository = repository ?? di<MyReviewRepository>();

  final MyReviewRepository _repository;

  final List<MyReviewItem> _items = [];
  List<MyReviewItem> get items => List.unmodifiable(_items);

  int _page = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  int get totalElements => _totalElements;

  bool _loading = false;
  bool get loading => _loading;
  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;
  Failure? _failure;

  /// 화면에 보일 실패 문구. 실패가 없으면 null.
  String? get error =>
      _failure == null ? null : MyReviewUiState.messageFor(_failure!);

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
  Map<String, List<MyReviewItem>> get grouped =>
      MyReviewUiState.groupByCreatedDate(_items);

  Future<void> load() async {
    _loading = true;
    _failure = null;
    _safeNotify();

    final result = await _repository.fetchMyRatings(page: 0);
    result.match(
      (failure) => _failure = failure,
      (page) {
        _items
          ..clear()
          ..addAll(page.ratings);
        _page = page.page;
        _totalPages = page.totalPages;
        _totalElements = page.totalElements;
      },
    );

    _loading = false;
    _safeNotify();
  }

  Future<void> loadMore() async {
    if (!hasMore || _loadingMore) return;
    _loadingMore = true;
    _safeNotify();

    final result = await _repository.fetchMyRatings(page: _page + 1);
    // 다음 페이지 실패는 화면 전체를 에러로 덮지 않는다 — 이미 보고 있는
    // 목록은 유효하다. 로그만 남기고 조용히 멈춘다(기존 동작과 같다).
    result.match(
      (failure) => debugPrint('[MyReviewVM] loadMore failed: $failure'),
      (page) {
        _items.addAll(page.ratings);
        _page = page.page;
        _totalPages = page.totalPages;
        _totalElements = page.totalElements;
      },
    );

    _loadingMore = false;
    _safeNotify();
  }

  /// 평가 삭제. 성공 시 목록에서 제거하고 누적 건수를 1 줄인다.
  ///
  /// 실패하면 호출부(화면)가 스낵바를 띄울 수 있게 false 를 돌려준다. 예전엔
  /// `rethrow` 였는데, 그러면 화면이 다시 `try/catch` 를 써야 했다.
  Future<bool> deleteRating(MyReviewItem item) async {
    final result = await _repository.deleteMyRating(
      gameId: item.gameId,
      participantId: item.participantId,
    );

    return result.match(
      (failure) {
        debugPrint('[MyReviewVM] delete failed: $failure');
        return false;
      },
      (_) {
        _items.removeWhere((e) => e.ratingId == item.ratingId);
        if (_totalElements > 0) _totalElements--;
        _safeNotify();
        return true;
      },
    );
  }
}
