import 'package:flutter/foundation.dart';

import '../../model/notice.dart';
import '../../repository/notice/notice_repository.dart';

/// 공지사항 목록 화면 상태.
///
/// 페이지 단위로 불러 [notices]에 누적하고, 스크롤 끝에서 [loadMore]로
/// 다음 페이지를 이어 붙인다.
class NoticeViewModel extends ChangeNotifier {
  NoticeViewModel({NoticeRepository? repository})
      : _repository = repository ?? NoticeRepository.instance {
    loadMore();
  }

  final NoticeRepository _repository;

  static const _pageSize = 20;

  final List<Notice> _notices = [];
  List<Notice> get notices => List.unmodifiable(_notices);

  bool _loading = false;
  bool get loading => _loading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _failed = false;
  bool get failed => _failed;

  int _page = 0;

  /// 다음 페이지를 불러 목록에 이어 붙인다.
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      final page =
          await _repository.fetchNotices(page: _page, size: _pageSize);
      _notices.addAll(page.notices);
      _hasMore = !page.last;
      _page += 1;
    } catch (e) {
      debugPrint('[NoticeViewModel] 목록 조회 실패: $e');
      _failed = _notices.isEmpty;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
