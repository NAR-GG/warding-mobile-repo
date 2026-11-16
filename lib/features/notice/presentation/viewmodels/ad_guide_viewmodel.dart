import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/core/di_container.dart';
import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/features/notice/domain/repositories/notice_repository.dart';

/// 광고 안내 페이지 상태. 공지 한 건을 slug 로 받아 보여준다.
///
/// 실패 종류는 구분하지 않는다 — 화면이 재시도 버튼만 보여주므로 "실패했다"
/// 하나로 충분하다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
class AdGuideViewModel extends ChangeNotifier {
  AdGuideViewModel({NoticeRepository? repository, required this.slug})
    : _repository = repository ?? di<NoticeRepository>();

  final NoticeRepository _repository;

  /// 받아올 공지의 slug.
  final String slug;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Notice? _notice;

  /// 받아온 공지. null 이면 아직 못 받았거나 실패했다.
  Notice? get notice => _notice;

  bool _loading = true;
  bool get loading => _loading;

  bool _failed = false;

  /// 조회가 끝났는데 공지가 없다 — 화면이 재시도 버튼을 보여준다.
  bool get failed => _failed;

  Future<void> load() async {
    _loading = true;
    _failed = false;
    notifyListeners();
    final result = await _repository.fetchPage(slug);
    if (_disposed) return;
    result.match(
      (failure) {
        debugPrint('[AdGuide] 페이지 조회 실패($slug): $failure');
        _failed = true;
      },
      (notice) => _notice = notice,
    );
    _loading = false;
    notifyListeners();
  }
}
