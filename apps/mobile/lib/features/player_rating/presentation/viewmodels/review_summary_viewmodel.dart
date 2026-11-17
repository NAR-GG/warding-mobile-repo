import 'package:flutter/foundation.dart';

import 'package:warding/features/player_rating/data/review_source.dart';
import 'package:warding/features/player_rating/domain/review_item.dart';

/// 다른 화면에 끼워 넣는 평점 한줄평 요약 섹션의 상태.
///
/// 한줄평이 달린 평점만 온다([ReviewSource] 계약). 비어 있으면 섹션 전체를
/// 숨기는 것이 호출부 몫이다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
class ReviewSummaryViewModel extends ChangeNotifier {
  ReviewSummaryViewModel({ReviewSource? source, this.count = 4})
    : _source = source ?? defaultReviewSource();

  final ReviewSource _source;

  /// 보여줄 한줄평 수.
  final int count;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<ReviewItem> _items = const [];

  /// 최대 [count] 건. 비어 있으면 호출부가 섹션을 숨긴다.
  List<ReviewItem> get items => _items.take(count).toList();

  int _gen = 0;

  /// 첫 응답(성공·실패 모두)이 오기 전 true — 스켈레톤을 그린다. 끝난 뒤
  /// 비어 있으면 섹션 전체를 숨긴다.
  bool _firstLoadPending = true;
  bool get loading => _firstLoadPending;

  Future<void> load() async {
    final gen = ++_gen;
    try {
      final items = await _source.fetchRecent();
      if (_disposed || gen != _gen) return;
      _items = items;
      _firstLoadPending = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[ReviewSummary] 평점 한줄평 조회 실패: $e');
      if (_disposed || gen != _gen) return;
      _firstLoadPending = false;
      notifyListeners();
    }
  }
}
