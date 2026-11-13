import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:warding/core/di_container.dart';
import 'package:warding/core/infrastructure/preference/notice_preference_repository.dart';
import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/features/notice/domain/repositories/notice_repository.dart';

/// 화면 상단에 끼워 넣는 공지 배너의 상태.
///
/// 공지 목록 화면은 [NoticeViewModel] 이다 — 그쪽은 전체 목록을 cursor 로
/// 넘기고, 이쪽은 "닫지 않은 것 중 최신 발행 하나"만 고른다.
///
/// 닫은 공지는 [NoticePreferenceRepository] 에 기록해 다시 뜨지 않게 한다.
/// 그 저장소는 일정 화면 배너와 공유한다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
/// 단 스플래시가 미리 받아 둔 캐시는 생성 시점에 읽는다 — 첫 프레임부터 그
/// 상태로 그려야 뒤늦게 배너가 끼어들어 아래 섹션을 밀지 않는다.
class NoticeBannerViewModel extends ChangeNotifier {
  NoticeBannerViewModel({
    NoticeRepository? repository,
    NoticePreferenceRepository? preferences,
  }) : _repository = repository ?? di<NoticeRepository>(),
       _preferences = preferences ?? NoticePreferenceRepository.instance {
    _notices = _repository.cachedPromoted ?? const [];
    _dismissedIds = _preferences.cachedValue ?? const {};
  }

  final NoticeRepository _repository;
  final NoticePreferenceRepository _preferences;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Notice> _notices = const [];
  Set<int> _dismissedIds = const {};

  /// 배너에 노출할 공지 — 닫지 않은 것 중 최신 발행. null 이면 배너 미표시.
  Notice? get notice {
    for (final notice in _notices) {
      if (!_dismissedIds.contains(notice.id)) return notice;
    }
    return null;
  }

  bool get visible => notice != null;

  /// 배너 ✕ — 닫은 공지를 기록해 다시 뜨지 않게 한다.
  void dismiss() {
    final current = notice;
    if (current == null) return;
    _dismissedIds = {..._dismissedIds, current.id};
    notifyListeners();
    unawaited(_preferences.addDismissedId(current.id));
  }

  Future<void> load() async {
    try {
      // 배너 실패는 화면의 한 줄이고 다른 섹션과 무관하다 — 빈 목록으로 둔다.
      final notices =
          (await _repository.fetchPromoted()).getOrElse((_) => const []);
      final dismissed = await _preferences.loadDismissedIds();
      if (_disposed) return;
      final before = notice;
      _notices = notices;
      // 조회하는 사이 ✕ 로 닫은 id 가 저장값 응답에 아직 없을 수 있다 —
      // 덮어쓰면 닫은 배너가 다시 뜨므로 합친다.
      _dismissedIds = {...dismissed, ..._dismissedIds};
      if (notice?.id != before?.id) notifyListeners();
    } catch (e) {
      debugPrint('[NoticeBanner] 배너 공지 조회 실패: $e');
    }
  }
}
