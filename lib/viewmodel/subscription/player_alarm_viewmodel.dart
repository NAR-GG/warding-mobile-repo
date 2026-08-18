import 'package:flutter/foundation.dart';

import '../../l10n/app_strings.dart';

import '../../model/player_subscription.dart';
import '../../repository/auth/auth_service.dart';
import '../../repository/subscription/subscription_repository.dart';

/// 마이 구독 설정 '선수' 탭 ViewModel.
///
/// 구독중인 선수 목록을 들고, 선수별 솔랭 시작/종료 알림 ON/OFF 를 관리한다.
///
/// 서버 API(`/player-subscriptions`)는 아직 알림 ON/OFF 필드를 주지도 받지도
/// 않는다. 지금은 두 값을 화면 상태로만 들고 있고, 필드가 생기면
/// [PlayerSubscription] 과 PUT 호출로 옮기면 된다.
/// 그래서 [isDirty]·[save] 도 아직 서버로 나가는 것이 없다.
class PlayerAlarmViewModel extends ChangeNotifier {
  PlayerAlarmViewModel({SubscriptionRepository? repository})
      : _repo = repository ?? SubscriptionRepository.instance {
    load();
  }

  final SubscriptionRepository _repo;

  bool _disposed = false;

  /// 구독중인 선수 목록.
  List<PlayerSubscription> _players = const [];
  List<PlayerSubscription> get players => _players;

  /// 선수별 솔랭 시작 알림 (playerId → ON/OFF). 키가 없으면 ON 으로 본다.
  final Map<int, bool> _soloRankStart = {};

  /// 선수별 솔랭 종료 알림 (playerId → ON/OFF). 키가 없으면 ON 으로 본다.
  final Map<int, bool> _soloRankEnd = {};

  bool soloRankStartOf(int playerId) => _soloRankStart[playerId] ?? true;
  bool soloRankEndOf(int playerId) => _soloRankEnd[playerId] ?? true;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// 로그인(JWT 보유) 여부. 비회원이면 탭 내용을 통째로 숨긴다.
  bool _loggedIn = true;
  bool get loggedIn => _loggedIn;

  /// 구독중인 선수 목록을 불러온다.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      // 비회원이면 API 를 호출하지 않고 조용히 비운다.
      final jwt = await AuthService.instance.jwt;
      if (jwt == null || jwt.isEmpty) {
        _loggedIn = false;
        _players = const [];
        return;
      }
      _loggedIn = true;
      _players = await _repo.fetchSubscribedPlayers();
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
  void setSoloRankStart(int playerId, bool value) {
    _soloRankStart[playerId] = value;
    _notify();
  }

  /// 솔랭 종료 알림 토글.
  void setSoloRankEnd(int playerId, bool value) {
    _soloRankEnd[playerId] = value;
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
