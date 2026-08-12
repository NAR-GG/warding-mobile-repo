import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/team_notification_subscription.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/subscription/subscription_repository.dart';

/// 마이페이지 '구독 팀 알림 설정' 섹션 ViewModel.
///
/// 구독중인 팀과 팀별 알림(세트 시작/종료·라이브) ON/OFF 를 들고,
/// `PUT /notification-subscriptions/{teamId}` 로 서버에 반영한다.
///
/// 반영 시점은 [deferSave] 로 고른다.
/// - false(기본) — 토글 즉시 PUT. 마이페이지 섹션.
/// - true — 토글은 화면에만 반영하고, [save] 를 불러야 PUT. '완료' 버튼이
///   있는 마이 구독 설정 화면.
class TeamAlarmViewModel extends ChangeNotifier {
  TeamAlarmViewModel({SubscriptionRepository? repository, this.deferSave = false})
      : _repo = repository ?? SubscriptionRepository.instance {
    load();
  }

  final SubscriptionRepository _repo;

  /// true 면 토글이 서버에 바로 가지 않고 [save] 호출까지 미뤄진다.
  final bool deferSave;

  bool _disposed = false;

  /// 구독중인 팀의 알림 설정 목록.
  List<TeamNotificationSubscription> _teams = const [];
  List<TeamNotificationSubscription> get teams => _teams;

  /// 마지막으로 서버와 맞춰진 상태. [deferSave] 일 때 변경 여부 판단·롤백에 쓴다.
  List<TeamNotificationSubscription> _saved = const [];

  /// 저장되지 않은 변경이 있는지. '완료' 버튼 활성 조건.
  bool get isDirty {
    for (final team in _teams) {
      final before = _saved.where((t) => t.teamId == team.teamId).firstOrNull;
      // 기준선에 없는 팀은 비교할 대상이 없으므로 변경으로 보지 않는다.
      if (before == null) continue;
      if (before.setStartEnabled != team.setStartEnabled ||
          before.setEndEnabled != team.setEndEnabled ||
          before.liveEventEnabled != team.liveEventEnabled) {
        return true;
      }
    }
    return false;
  }

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// 로그인(JWT 보유) 여부. 비회원이면 섹션을 통째로 숨긴다.
  bool _loggedIn = true;
  bool get loggedIn => _loggedIn;

  /// 구독중인 팀 알림 목록을 불러온다.
  ///
  /// [keepUnsaved] 면 저장 전 토글 변경을 그대로 둔 채 팀 목록만 갱신한다.
  /// 구독 관리 화면에 다녀왔을 때처럼, 팀이 늘거나 빠졌을 수는 있지만
  /// 유저가 만지던 값은 잃지 않아야 하는 경우에 쓴다.
  Future<void> load({bool keepUnsaved = false}) async {
    // 유지할 변경분을 미리 떠 둔다(서버 응답으로 _teams 가 덮이기 전에).
    final pending = keepUnsaved && isDirty
        ? {for (final t in _teams) t.teamId: t}
        : const <int, TeamNotificationSubscription>{};

    _isLoading = true;
    _error = null;
    _notify();
    try {
      // 비회원이면 `/me` API 를 호출하지 않고 조용히 섹션을 숨긴다.
      final jwt = await AuthService.instance.jwt;
      if (jwt == null || jwt.isEmpty) {
        _loggedIn = false;
        _teams = const [];
        _saved = const [];
        return;
      }
      _loggedIn = true;
      final all = await _repo.fetchTeamNotifications();
      // 마이페이지 섹션은 '구독중인 팀'만 보여 준다.
      final fetched = all.where((t) => t.subscribed).toList();
      // 기준선은 언제나 서버 값. 화면 값만 유지할 변경분으로 덮는다.
      _saved = fetched;
      _teams = [
        for (final t in fetched) pending[t.teamId] ?? t,
      ];
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

  /// [teamId] 항목에 [change] 를 적용한다.
  ///
  /// [deferSave] 면 화면에만 반영하고 PUT 은 [save] 로 미룬다.
  /// 아니면 화면에 낙관적으로 반영한 뒤 바로 PUT 하고, 실패하면 되돌린다.
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
    if (deferSave) return;
    try {
      await _repo.updateTeamNotification(
        teamId,
        setStartEnabled: after.setStartEnabled,
        setEndEnabled: after.setEndEnabled,
        liveEventEnabled: after.liveEventEnabled,
      );
      _saved = _teams;
    } catch (e) {
      // 실패 시 이전 상태로 롤백.
      _teams = [
        for (final t in _teams) t.teamId == teamId ? before : t,
      ];
      _notify();
      debugPrint('[TeamAlarm] 설정 변경 실패, 롤백: $e');
    }
  }

  /// 미뤄 둔 변경을 서버에 반영한다. 바뀐 팀만 PUT 한다.
  ///
  /// 전부 성공하면 true. 하나라도 실패하면 실패한 팀만 이전 값으로 되돌리고
  /// false 를 반환한다(성공한 팀은 그대로 두어 재시도 시 중복 PUT 을 피한다).
  Future<bool> save() async {
    if (_isSaving || !isDirty) return true;
    _isSaving = true;
    _error = null;
    _notify();

    final saved = [..._saved];
    var ok = true;
    for (final team in _teams) {
      final before = saved.firstWhere(
        (t) => t.teamId == team.teamId,
        orElse: () => team,
      );
      if (before.setStartEnabled == team.setStartEnabled &&
          before.setEndEnabled == team.setEndEnabled &&
          before.liveEventEnabled == team.liveEventEnabled) {
        continue;
      }
      try {
        await _repo.updateTeamNotification(
          team.teamId,
          setStartEnabled: team.setStartEnabled,
          setEndEnabled: team.setEndEnabled,
          liveEventEnabled: team.liveEventEnabled,
        );
        // 성공한 팀은 기준선을 새 값으로 옮긴다.
        final i = saved.indexWhere((t) => t.teamId == team.teamId);
        if (i >= 0) saved[i] = team;
      } catch (e) {
        ok = false;
        // 실패한 팀만 화면을 이전 값으로 되돌린다.
        _teams = [
          for (final t in _teams) t.teamId == team.teamId ? before : t,
        ];
        debugPrint('[TeamAlarm] 저장 실패, 롤백: $e');
      }
    }
    _saved = saved;
    if (!ok) {
      _error = appStrings?.teamAlarmSaveFailed ?? 'Failed to save alarm settings';
    }
    _isSaving = false;
    _notify();
    return ok;
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
