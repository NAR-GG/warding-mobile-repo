import 'dart:async';


import 'package:warding/core/di_container.dart';
import 'package:warding/features/notice/domain/notice.dart';
import 'package:warding/features/notice/domain/repositories/notice_repository.dart';

/// 공지 상세 화면의 부수 효과를 담는다.
///
/// 상태는 없다 — 공지 본문은 화면이 이미 들고 들어온다. 그런데도 ViewModel 을
/// 둔 이유는 **화면이 repository 를 알지 않게** 하려는 것이다. 콜백으로
/// 받으면 호출부 3곳(홈·공지 목록·광고 안내)이 대신 알게 되는데 그중 둘이
/// 화면이라 더 나빠진다.
class NoticeDetailViewModel {
  NoticeDetailViewModel({NoticeRepository? repository})
    : _repository = repository ?? di<NoticeRepository>();

  final NoticeRepository _repository;

  /// 조회수 집계 — 화면 진입 1회.
  ///
  /// 임시저장은 ADMIN 검수 열람이라 세지 않는다. 응답을 기다리지 않는다 —
  /// 실패해도 화면은 그대로다.
  void markViewed(Notice notice) {
    if (notice.isDraft) return;
    unawaited(_repository.markViewed(notice.id));
  }
}
