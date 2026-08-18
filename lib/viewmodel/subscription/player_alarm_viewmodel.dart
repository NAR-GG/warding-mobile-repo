import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/player_subscription.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/subscription/subscription_repository.dart';

/// 마이 구독 설정 '선수' 탭 ViewModel.
///
/// 구독중인 선수 목록을 들고, 선수별 솔랭 시작/종료 알림 ON/OFF 를 관리한다.
/// `PUT /player-subscriptions/{playerId}` 로 서버에 반영한다.
///
/// 반영 시점은 [deferSave] 로 고른다.
/// - false(기본) — 토글 즉시 PUT.
/// - true — 토글은 화면에만 반영하고, [save] 를 불러야 PUT. '완료' 버튼이
///   있는 마이 구독 설정 화면.
class PlayerAlarmViewModel extends ChangeNotifier {
  PlayerAlarmViewModel({SubscriptionRepository? repository, this.deferSave = false})
      : _repo = repository ?? SubscriptionRepository.instance {
    load();
  }

  final SubscriptionRepository _repo;

  /// true 면 토글이 서버에 바로 가지 않고 [save] 호출까지 미뤄진다.
  final bool deferSave;

  bool _disposed = false;

  /// 구독중인 선수 목록.
  List<PlayerSubscription> _players = const [];
  List<PlayerSubscription> get players => _players;

  /// 마지막으로 서버와 맞춰진 상태. [deferSave] 일 때 변경 여부 판단·롤백에 쓴다.
  List<PlayerSubscription> _saved = const [];

  /// 저장되지 않은 변경이 있는지. '완료' 버튼 활성 조건.
  bool get isDirty {
    for (final player in _players) {
      final before = _saved
          .where((p) => p.playerId == player.playerId)
          .firstOrNull;
      // 기준선에 없는 선수는 비교할 대상이 없으므로 변경으로 보지 않는다.
      if (before == null) continue;
      if (_alarmFieldsDiffer(before, player)) return true;
    }
    return false;
  }

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// 로그인(JWT 보유) 여부. 비회원이면 탭 내용을 통째로 숨긴다.
  bool _loggedIn = true;
  bool get loggedIn => _loggedIn;

  /// 구독중인 선수 목록을 불러온다.
  ///
  /// [keepUnsaved] 면 저장 전 토글 변경을 그대로 둔 채 목록만 갱신한다.
  /// 구독 관리 화면에 다녀왔을 때처럼, 선수가 늘거나 빠졌을 수는 있지만
  /// 유저가 만지던 값은 잃지 않아야 하는 경우에 쓴다.
  Future<void> load({bool keepUnsaved = false}) async {
    // 유지할 변경분을 미리 떠 둔다(서버 응답으로 _players 가 덮이기 전에).
    final pending = keepUnsaved && isDirty
        ? {for (final p in _players) p.playerId: p}
        : const <int, PlayerSubscription>{};

    _isLoading = true;
    _error = null;
    _notify();
    try {
      // 비회원이면 API 를 호출하지 않고 조용히 비운다.
      final jwt = await AuthService.instance.jwt;
      if (jwt == null || jwt.isEmpty) {
        _loggedIn = false;
        _players = const [];
        _saved = const [];
        return;
      }
      _loggedIn = true;
      final fetched = await _repo.fetchSubscribedPlayers();
      // 기준선은 언제나 서버 값. 화면 값만 유지할 변경분으로 덮는다.
      _saved = fetched;
      _players = [for (final p in fetched) pending[p.playerId] ?? p];
    } catch (e, st) {
      _error =
          appStrings?.subscriptionLoadFailed ?? 'Failed to load subscriptions';
      debugPrint('[PlayerAlarm] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// 솔랭 시작 알림 토글.
  Future<void> setSoloRankStart(int playerId, bool value) {
    debugPrint('[PlayerAlarm] 솔랭 시작 알림 토글 → player=$playerId value=$value');
    return _update(playerId, (p) => p.copyWith(startEnabled: value));
  }

  /// 솔랭 종료 알림 토글.
  Future<void> setSoloRankEnd(int playerId, bool value) {
    debugPrint('[PlayerAlarm] 솔랭 종료 알림 토글 → player=$playerId value=$value');
    return _update(playerId, (p) => p.copyWith(endEnabled: value));
  }

  static bool _alarmFieldsDiffer(PlayerSubscription a, PlayerSubscription b) =>
      a.startEnabled != b.startEnabled || a.endEnabled != b.endEnabled;

  /// [playerId] 항목에 [change] 를 적용한다.
  ///
  /// [deferSave] 면 화면에만 반영하고 PUT 은 [save] 로 미룬다.
  /// 아니면 화면에 낙관적으로 반영한 뒤 바로 PUT 하고, 실패하면 되돌린다.
  Future<void> _update(
    int playerId,
    PlayerSubscription Function(PlayerSubscription) change,
  ) async {
    final before = _players.firstWhere((p) => p.playerId == playerId);
    final after = change(before);
    _players = [for (final p in _players) p.playerId == playerId ? after : p];
    _notify();
    if (deferSave) return;
    try {
      await _repo.updatePlayerAlarm(
        playerId,
        startEnabled: after.startEnabled,
        endEnabled: after.endEnabled,
      );
      _saved = _players;
    } catch (e) {
      // 실패 시 이전 상태로 롤백.
      _players = [
        for (final p in _players) p.playerId == playerId ? before : p,
      ];
      _notify();
      debugPrint('[PlayerAlarm] 설정 변경 실패, 롤백: $e');
    }
  }

  /// 미뤄 둔 변경을 서버에 반영한다. 바뀐 선수만 PUT 한다.
  ///
  /// 전부 성공하면 true. 하나라도 실패하면 실패한 선수만 이전 값으로 되돌리고
  /// false 를 반환한다(성공한 선수는 그대로 두어 재시도 시 중복 PUT 을 피한다).
  Future<bool> save() async {
    if (_isSaving || !isDirty) return true;
    _isSaving = true;
    _error = null;
    _notify();

    final saved = [..._saved];
    var ok = true;
    for (final player in _players) {
      final before = saved.firstWhere(
        (p) => p.playerId == player.playerId,
        orElse: () => player,
      );
      if (!_alarmFieldsDiffer(before, player)) {
        continue;
      }
      try {
        await _repo.updatePlayerAlarm(
          player.playerId,
          startEnabled: player.startEnabled,
          endEnabled: player.endEnabled,
        );
        // 성공한 선수는 기준선을 새 값으로 옮긴다.
        final i = saved.indexWhere((p) => p.playerId == player.playerId);
        if (i >= 0) saved[i] = player;
      } catch (e) {
        ok = false;
        // 실패한 선수만 화면을 이전 값으로 되돌린다.
        _players = [
          for (final p in _players) p.playerId == player.playerId ? before : p,
        ];
        debugPrint('[PlayerAlarm] 저장 실패, 롤백: $e');
      }
    }
    _saved = saved;
    if (!ok) {
      _error =
          appStrings?.playerAlarmSaveFailed ?? 'Failed to save alarm settings';
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
