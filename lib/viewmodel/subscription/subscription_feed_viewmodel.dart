import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../model/member_notification.dart';
import '../../repository/notification/member_notification_repository.dart';

/// 마이구독 피드 ViewModel — 서버 알림 리스트(`/api/mobile/me/notifications`)를
/// 들고 있다. 화면 진입·복귀 시 다시 읽는다.
///
/// 타입/선수 필터는 UI 가 멀티셀렉트라 단일 type 쿼리로 표현하기 어려워,
/// 여기선 전체를 받아두고 화면에서 클라이언트 필터링한다.
///
/// 온보딩에서 알림 권한을 건너뛴 회원을 위해, 알림 권한 상태도 함께 들고 있다.
class SubscriptionFeedViewModel extends ChangeNotifier {
  SubscriptionFeedViewModel({MemberNotificationRepository? repository})
      : _repo = repository ?? MemberNotificationRepository.instance {
    load();
    refreshNotificationPermission();
  }

  final MemberNotificationRepository _repo;
  bool _disposed = false;

  /// 한 번에 받아오는 건수. 목록 끝에 닿으면 [loadMore] 로 다음 페이지를 잇는다.
  static const int _pageSize = 50;

  List<MemberNotification> _notifications = const [];
  List<MemberNotification> get notifications => _notifications;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 다음 페이지를 이어 받는 중인지. 하단 스켈레톤 표시에 쓴다.
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  /// 마지막으로 받은 페이지 번호.
  int _page = 0;

  /// 서버에 다음 페이지가 남았는지. false 면 [loadMore] 는 아무것도 하지 않는다.
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  String? _error;
  String? get error => _error;

  // 낙관적으로 true 로 시작해, 최초 확인 전까지 배너가 잠깐 나타났다 사라지는
  // 깜빡임을 막는다.
  bool _notificationPermissionGranted = true;
  bool get notificationPermissionGranted => _notificationPermissionGranted;

  /// 알림 권한 상태를 다시 확인한다(진입·복귀 시). 온보딩을 건너뛰었거나
  /// '허용 안 함'을 눌러 미허용 상태면 화면에 안내 배너를 띄운다.
  Future<void> refreshNotificationPermission() async {
    final status = await Permission.notification.status;
    final granted = status.isGranted;
    if (granted != _notificationPermissionGranted) {
      _notificationPermissionGranted = granted;
      _notify();
    }
  }

  /// 안내 배너 탭 → 알림 권한을 요청한다. 영구 거부 상태면 앱 설정으로 보낸다.
  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      _notificationPermissionGranted = true;
      _notify();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  /// 서버에서 알림을 처음부터 다시 읽는다(진입·복귀·당겨서 새로고침).
  /// 이어받던 페이지 상태도 초기화한다.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final pageData = await _repo.fetchNotifications(page: 0, size: _pageSize);
      _notifications = pageData.notifications;
      _unreadCount = pageData.unreadCount;
      _page = pageData.page;
      _hasMore = pageData.hasMore;
    } catch (e, st) {
      _error = appStrings?.notificationLoadFailed ?? 'Failed to load notifications.';
      debugPrint('[Feed] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// 다음 페이지를 이어 받는다(목록 끝에 닿았을 때).
  ///
  /// 중복 호출·마지막 페이지·초기 로딩 중에는 아무것도 하지 않는다.
  /// 실패해도 [error] 를 세우지 않는다 — 이미 받은 목록은 그대로 보이는 게
  /// 나아서, 다음 스크롤에 자연히 재시도된다.
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    _isLoadingMore = true;
    _notify();
    try {
      final pageData = await _repo.fetchNotifications(
        page: _page + 1,
        size: _pageSize,
      );
      // 중복 id 는 걸러낸다 — 이어받는 사이 새 알림이 쌓이면 서버 페이지가
      // 한 칸씩 밀려 같은 건이 다시 내려올 수 있다.
      final seen = _notifications.map((n) => n.id).toSet();
      _notifications = [
        ..._notifications,
        ...pageData.notifications.where((n) => !seen.contains(n.id)),
      ];
      _unreadCount = pageData.unreadCount;
      _page = pageData.page;
      _hasMore = pageData.hasMore;
    } catch (e, st) {
      debugPrint('[Feed] loadMore 에러: $e\n$st');
    } finally {
      _isLoadingMore = false;
      _notify();
    }
  }

  /// 단건 읽음 처리(낙관적 갱신 후 서버 호출).
  Future<void> markRead(MemberNotification n) async {
    if (n.read) return;
    _notifications = _notifications
        .map((x) => x.id == n.id ? x.copyWith(read: true) : x)
        .toList();
    if (_unreadCount > 0) _unreadCount--;
    _notify();
    try {
      await _repo.markRead(n.id);
    } catch (e) {
      debugPrint('[Feed] markRead 실패(무시): $e');
    }
  }

  /// 단건 삭제(낙관적 제거 후 서버 호출, 실패 시 원위치 복구).
  Future<void> delete(MemberNotification n) async {
    final idx = _notifications.indexWhere((x) => x.id == n.id);
    if (idx < 0) return;
    final removed = _notifications[idx];
    _notifications = [..._notifications]..removeAt(idx);
    if (!removed.read && _unreadCount > 0) _unreadCount--;
    _notify();
    try {
      await _repo.delete(n.id);
    } catch (e) {
      debugPrint('[Feed] delete 실패, 복구: $e');
      _notifications = [..._notifications]..insert(idx, removed);
      if (!removed.read) _unreadCount++;
      _notify();
      rethrow;
    }
  }

  /// 전체 읽음(낙관적 반영 후 서버 호출, 실패 시 복구).
  Future<void> markAllRead() async {
    if (_unreadCount == 0) return;
    final backup = _notifications;
    final backupUnread = _unreadCount;
    _notifications = _notifications.map((x) => x.copyWith(read: true)).toList();
    _unreadCount = 0;
    _notify();
    try {
      await _repo.markAllRead();
    } catch (e) {
      debugPrint('[Feed] 전체읽음 실패, 복구: $e');
      _notifications = backup;
      _unreadCount = backupUnread;
      _notify();
    }
  }

  /// 전체 삭제(낙관적 비움 후 서버 호출, 실패 시 복구).
  Future<void> deleteAll() async {
    final backup = _notifications;
    final backupUnread = _unreadCount;
    _notifications = const [];
    _unreadCount = 0;
    _notify();
    try {
      await _repo.deleteAll();
    } catch (e) {
      debugPrint('[Feed] 전체삭제 실패, 복구: $e');
      _notifications = backup;
      _unreadCount = backupUnread;
      _notify();
      rethrow;
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
