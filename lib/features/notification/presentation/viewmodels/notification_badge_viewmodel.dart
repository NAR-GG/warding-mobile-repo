import 'package:flutter/foundation.dart';

import 'package:warding/core/di_container.dart';
import 'package:warding/core/error/failure_exception.dart';
import 'package:warding/domain/repositories/member_notification_repository.dart';

/// 헤더 벨 아이콘의 미읽음 배지 상태.
///
/// 벨이 여는 화면(마이구독)의 피드와 **같은 범위**로 세야 한다 — 거기서 다
/// 읽었는데 배지가 남으면 유저는 지울 방법이 없다. 그 피드는
/// `SubscriptionFeedViewModel` 을 group 없이(=전체) 쓰므로 여기도 전체다.
/// 벨 목적지를 바꾸면 이 범위도 함께 맞춘다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [refresh] 로 정한다.
class NotificationBadgeViewModel extends ChangeNotifier {
  NotificationBadgeViewModel({MemberNotificationRepository? repository})
    : _repository = repository ?? di<MemberNotificationRepository>();

  final MemberNotificationRepository _repository;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  int _unreadCount = 0;

  /// 미읽음 수. 0 이면 배지를 숨긴다.
  int get unreadCount => _unreadCount;

  /// 미읽음 수를 다시 센다. 알림 화면에서 돌아올 때도 부른다.
  /// 비회원(JWT 없음)·실패는 0(배지 숨김)으로 조용히 넘어간다.
  Future<void> refresh() async {
    var count = 0;
    try {
      final page = (await _repository.fetchNotifications(page: 0, size: 1))
          .getOrElse((f) => throw FailureException(f));
      count = page.unreadCount;
    } catch (e) {
      debugPrint('[NotificationBadge] 미읽음 수 조회 실패(비회원 포함): $e');
    }
    if (_disposed || count == _unreadCount) return;
    _unreadCount = count;
    notifyListeners();
  }
}
