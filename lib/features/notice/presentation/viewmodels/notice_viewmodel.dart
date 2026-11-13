import 'package:flutter/foundation.dart';

import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/core/di_container.dart';
import 'package:warding/features/notice/domain/repositories/notice_repository.dart';

/// 공지사항 목록 화면 상태.
///
/// 페이지 단위로 불러 [notices]에 누적하고, 스크롤 끝에서 [loadMore]로
/// 다음 페이지를 이어 붙인다.
class NoticeViewModel extends ChangeNotifier {
  NoticeViewModel({NoticeRepository? repository})
      : _repository = repository ?? di<NoticeRepository>() {
    loadMore();
  }

  final NoticeRepository _repository;

  static const _pageSize = 20;

  /// 첫 조회가 생성자에서 시작되므로 화면이 뜨기도 전에 요청이 떠 있다.
  /// 공지를 열자마자 뒤로 가면 dispose 뒤에 응답이 와서 `notifyListeners()`
  /// 가 예외를 던진다 — 요청 시간 전체가 노출 구간이다.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

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
    _safeNotify();
    final result =
        await _repository.fetchNotices(page: _page, size: _pageSize);
    result.match(
      (failure) {
        debugPrint('[NoticeViewModel] 목록 조회 실패: $failure');
        // 이미 받아 둔 목록이 있으면 실패 화면으로 덮지 않는다 — 다음
        // 페이지를 못 받은 것이지 지금까지 본 것이 무효가 된 게 아니다.
        _failed = _notices.isEmpty;
      },
      (page) {
        _notices.addAll(page.notices);
        _hasMore = !page.last;
        _page += 1;
      },
    );
    _loading = false;
    _safeNotify();
  }
}
