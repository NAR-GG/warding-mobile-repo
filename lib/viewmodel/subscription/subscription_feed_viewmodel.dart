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
  SubscriptionFeedViewModel({
    MemberNotificationRepository? repository,
    this.group,
  }) : _repo = repository ?? MemberNotificationRepository.instance {
    load();
    refreshNotificationPermission();
  }

  final MemberNotificationRepository _repo;

  /// 묶음 필터(예: 'COMMUNITY'). 알림함은 커뮤니티 전용이라 이걸 걸고,
  /// 마이구독은 null(전체)로 그대로 쓴다. unreadCount·모두읽음도 이 범위다.
  final String? group;
  bool _disposed = false;

  /// 한 번에 받아오는 건수. 목록 끝에 닿으면 [loadMore] 로 다음 페이지를 잇는다.
  static const int _pageSize = 50;

  List<MemberNotification> _notifications = const [];
  List<MemberNotification> get notifications => _notifications;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// 첫 [load] 가 성공으로 끝났는지. `_unreadCount` 는 0 에서 시작하므로
  /// 이 플래그가 없으면 "아직 못 받음"과 "받아보니 0건"을 구분할 수 없다
  /// ([markAllReadOnExit] 가 전자를 후자로 오해해 요청을 건너뛰었다).
  bool _loadedOnce = false;

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
      final pageData = await _repo.fetchNotifications(
        group: group,
        page: 0,
        size: _pageSize,
      );
      _notifications = pageData.notifications;
      _unreadCount = pageData.unreadCount;
      _page = pageData.page;
      _hasMore = pageData.hasMore;
      _loadedOnce = true;
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
        group: group,
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
      await _repo.markAllRead(group: group);
    } catch (e) {
      debugPrint('[Feed] 전체읽음 실패, 복구: $e');
      _notifications = backup;
      _unreadCount = backupUnread;
      _notify();
    }
  }

  /// 화면을 나갈 때 이 범위를 전부 읽음으로 넘긴다 — 유저가 목록을 눈으로
  /// 확인했으므로 홈 벨 배지가 남아 있을 이유가 없다.
  ///
  /// [markAllRead] 와 달리 목록 상태를 건드리지 않는다. 화면이 사라지는
  /// 시점이라 낙관적 갱신을 보여줄 UI 가 없고(그래서 보라색 미읽음 강조가
  /// 머무는 동안은 그대로 유지된다), 실패해도 복구할 대상이 없다. 다음 진입
  /// 때 서버 값을 그대로 다시 받으므로 실패는 조용히 넘긴다.
  ///
  /// 화면 전환 **전에** 불러 완료를 기다린다([SubscriptionScreen._leaveTo]) —
  /// 홈의 미읽음 조회보다 늦게 끝나면 배지가 옛 수로 남는다. `dispose` 경로는
  /// 그 전환을 거치지 않는 이탈(안드로이드 뒤로가기 등)만 받는 보완책이다.
  ///
  /// 건너뛰는 건 **첫 조회가 끝났고 그 결과가 0건일 때뿐**이다. `_unreadCount`
  /// 만 보면 아직 응답이 안 온 초기값 0 까지 "읽을 게 없다"로 오해해, 목록이
  /// 뜨기 전에 나간 사용자의 알림이 미읽음으로 남는다.
  Future<void> markAllReadOnExit() async {
    if (_loadedOnce && _unreadCount == 0) return;
    try {
      await _repo.markAllRead(group: group);
    } catch (e) {
      debugPrint('[Feed] 이탈 시 전체읽음 실패(무시): $e');
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
