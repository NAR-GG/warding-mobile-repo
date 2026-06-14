import 'package:flutter/foundation.dart';

import '../../model/solo_rank_notification.dart';
import '../../repository/notification/solo_rank_notification_store.dart';

/// 마이구독 피드 ViewModel — 기기에 저장된 솔랭 알림 목록을 들고 있다.
class SubscriptionFeedViewModel extends ChangeNotifier {
  SubscriptionFeedViewModel({SoloRankNotificationStore? store})
      : _store = store ?? SoloRankNotificationStore.instance {
    load();
  }

  final SoloRankNotificationStore _store;
  bool _disposed = false;

  List<SoloRankNotification> _notifications = const [];
  List<SoloRankNotification> get notifications => _notifications;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 저장된 알림을 다시 읽는다(화면 진입·복귀 시).
  Future<void> load() async {
    _isLoading = true;
    _notify();
    _notifications = await _store.loadAll();
    _isLoading = false;
    _notify();
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
