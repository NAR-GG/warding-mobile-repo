import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/team_notification_subscription.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/subscription/subscription_repository.dart';

/// 마이페이지 '구독 팀 알림 설정' 섹션 ViewModel.
///
/// 구독중인 팀과 팀별 알림(세트 시작/종료·라이브) ON/OFF 를 들고,
/// 토글 시 `PUT /notification-subscriptions/{teamId}` 로 서버에 반영한다.
class TeamAlarmViewModel extends ChangeNotifier {
  TeamAlarmViewModel({SubscriptionRepository? repository})
      : _repo = repository ?? SubscriptionRepository.instance {
    load();
  }

  final SubscriptionRepository _repo;
  bool _disposed = false;

  /// 구독중인 팀의 알림 설정 목록.
  List<TeamNotificationSubscription> _teams = const [];
  List<TeamNotificationSubscription> get teams => _teams;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// 로그인(JWT 보유) 여부. 비회원이면 섹션을 통째로 숨긴다.
  bool _loggedIn = true;
  bool get loggedIn => _loggedIn;

  /// 구독중인 팀 알림 목록을 불러온다.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      // 비회원이면 `/me` API 를 호출하지 않고 조용히 섹션을 숨긴다.
      final jwt = await AuthService.instance.jwt;
      if (jwt == null || jwt.isEmpty) {
        _loggedIn = false;
        _teams = const [];
        return;
      }
      _loggedIn = true;
      final all = await _repo.fetchTeamNotifications();
      // 마이페이지 섹션은 '구독중인 팀'만 보여 준다.
      _teams = all.where((t) => t.subscribed).toList();
    } catch (e, st) {
      _error = appStrings?.teamAlarmLoadFailed ?? 'Failed to load team alarm settings';
      debugPrint('[TeamAlarm] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// 세트 시작 알림 토글.
  Future<void> setSetStart(int teamId, bool value) =>
      _update(teamId, (t) => t.copyWith(setStartEnabled: value));

  /// 세트 종료 알림 토글.
  Future<void> setSetEnd(int teamId, bool value) =>
      _update(teamId, (t) => t.copyWith(setEndEnabled: value));

  /// 라이브 이벤트 알림 토글.
  Future<void> setLiveEvent(int teamId, bool value) =>
      _update(teamId, (t) => t.copyWith(liveEventEnabled: value));

  /// [teamId] 항목에 [change] 를 적용하고 서버에 PUT 한다.
  /// 먼저 화면에 낙관적으로 반영하고, 실패하면 되돌린다.
  Future<void> _update(
    int teamId,
    TeamNotificationSubscription Function(TeamNotificationSubscription) change,
  ) async {
    final before = _teams.firstWhere((t) => t.teamId == teamId);
    final after = change(before);
    _teams = [
      for (final t in _teams) t.teamId == teamId ? after : t,
    ];
    _notify();
    try {
      await _repo.updateTeamNotification(
        teamId,
        setStartEnabled: after.setStartEnabled,
        setEndEnabled: after.setEndEnabled,
        liveEventEnabled: after.liveEventEnabled,
      );
    } catch (e) {
      // 실패 시 이전 상태로 롤백.
      _teams = [
        for (final t in _teams) t.teamId == teamId ? before : t,
      ];
      _notify();
      debugPrint('[TeamAlarm] 설정 변경 실패, 롤백: $e');
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
