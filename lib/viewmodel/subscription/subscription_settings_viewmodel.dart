import 'package:flutter/foundation.dart';

import '../../model/player_subscription.dart';
import '../../model/team_notification_subscription.dart';
import '../../repository/subscription/subscription_repository.dart';

/// 구독 설정 화면 ViewModel.
///
/// 구독중인 팀·선수, 전체(검색) 목록을 들고 구독 토글을 처리한다.
/// 팀은 `notification-subscriptions`, 선수는 `player-subscriptions` API 를 쓴다.
class SubscriptionSettingsViewModel extends ChangeNotifier {
  SubscriptionSettingsViewModel({SubscriptionRepository? repository})
      : _repo = repository ?? SubscriptionRepository.instance {
    load();
  }

  final SubscriptionRepository _repo;
  bool _disposed = false;

  /// 한 페이지에 받을 선수 수. 백엔드 상한(100)에 맞춰 현재 LCK 로스터(약 60여 명)를
  /// 한 번에 받는다. 로스터가 100을 넘어가면 [loadMorePlayers] 무한 스크롤로 이어 받는다.
  static const int _pageSize = 100;

  List<PlayerSubscription> _subscribedPlayers = const [];
  List<PlayerSubscription> get subscribedPlayers => _subscribedPlayers;

  /// 전체 목록 '선수' 탭 — 검색 결과(구독 여부 포함). 페이지네이션으로 누적된다.
  List<PlayerSubscription> _availablePlayers = const [];
  List<PlayerSubscription> get availablePlayers => _availablePlayers;

  /// 현재까지 받은 '선수' 페이지(0-based)와 전체 페이지/인원.
  int _availPage = 0;
  int _availTotalPages = 1;
  int _availTotalElements = 0;

  /// 검색 조건에 맞는 전체 선수 수(현재 화면에 보이는 수가 아니라 총합).
  int get availablePlayersTotal => _availTotalElements;

  /// 더 불러올 선수 페이지가 남아있는지.
  bool get hasMorePlayers => _availPage + 1 < _availTotalPages;

  /// 다음 페이지를 불러오는 중인지. (하단 로딩 인디케이터용)
  bool _loadingMorePlayers = false;
  bool get loadingMorePlayers => _loadingMorePlayers;

  /// 전체 목록 '팀' 탭 — 구독 여부 포함. 구독중 팀은 여기서 필터한다.
  List<TeamNotificationSubscription> _availableTeams = const [];
  List<TeamNotificationSubscription> get availableTeams => _availableTeams;

  /// 상단 '구독중인 팀' 섹션 — 전체 팀에서 구독중만 추린다.
  List<TeamNotificationSubscription> get subscribedTeams =>
      _availableTeams.where((t) => t.subscribed).toList();

  String _query = '';
  String get query => _query;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  /// '구독 가능 선수'를 아직 불러오는 중인지. (가장 느린 조회라 별도 표시용)
  bool _loadingAvailablePlayers = false;
  bool get loadingAvailablePlayers => _loadingAvailablePlayers;

  /// 초기 데이터(구독중 선수 + 전체 선수 + 전체 팀)를 불러온다.
  ///
  /// 세 조회를 병렬로 실행하되, **각자 끝나는 대로** 화면을 갱신한다.
  /// 보통 빠른 '구독중 선수·팀'을 먼저 보여주고, 느린 '가능 선수'는 나중에 채운다.
  Future<void> load() async {
    _isLoading = true;
    _loadingAvailablePlayers = true;
    _error = null;
    _notify();

    final subscribed = _repo.fetchSubscribedPlayers().then((v) {
      _subscribedPlayers = v;
      _notify();
    });
    final teams = _repo.fetchAvailableTeams().then((v) {
      _availableTeams = v;
      _notify();
    });
    final available = _repo
        .searchAvailablePlayers(query: _query, page: 0, size: _pageSize)
        .then((v) {
      _availablePlayers = v.content;
      _availPage = v.page;
      _availTotalPages = v.totalPages;
      _availTotalElements = v.totalElements;
      _loadingAvailablePlayers = false;
      _notify();
    });

    try {
      await Future.wait([subscribed, teams, available]);
    } catch (e, st) {
      _error = e;
      debugPrint('[Subscription] load 에러: $e\n$st');
    } finally {
      _isLoading = false;
      _loadingAvailablePlayers = false;
      _notify();
    }
  }

  /// 검색어로 전체 선수 목록을 다시 조회한다. 첫 페이지부터 다시 시작한다.
  Future<void> searchPlayers(String query) async {
    _query = query;
    try {
      final v = await _repo.searchAvailablePlayers(
          query: query, page: 0, size: _pageSize);
      _availablePlayers = v.content;
      _availPage = v.page;
      _availTotalPages = v.totalPages;
      _availTotalElements = v.totalElements;
      _notify();
    } catch (e) {
      debugPrint('[Subscription] searchPlayers 에러: $e');
    }
  }

  /// 다음 페이지 선수를 이어 붙인다. (무한 스크롤)
  ///
  /// 더 받을 페이지가 없거나 이미 로딩 중이면 아무것도 하지 않는다.
  Future<void> loadMorePlayers() async {
    if (!hasMorePlayers || _loadingMorePlayers) return;
    _loadingMorePlayers = true;
    _notify();
    try {
      final v = await _repo.searchAvailablePlayers(
        query: _query,
        page: _availPage + 1,
        size: _pageSize,
      );
      _availablePlayers = [..._availablePlayers, ...v.content];
      _availPage = v.page;
      _availTotalPages = v.totalPages;
      _availTotalElements = v.totalElements;
    } catch (e) {
      debugPrint('[Subscription] loadMorePlayers 에러: $e');
    } finally {
      _loadingMorePlayers = false;
      _notify();
    }
  }

  /// 선수 구독을 토글한다. [subscribed] 는 현재(토글 전) 상태.
  Future<void> togglePlayer(int playerId, bool subscribed) async {
    try {
      if (subscribed) {
        await _repo.unsubscribePlayer(playerId);
      } else {
        await _repo.subscribePlayer(playerId);
      }
      _applyPlayerToggle(playerId, !subscribed);
      _notify();
    } catch (e) {
      debugPrint('[Subscription] togglePlayer 에러: $e');
    }
  }

  /// 팀 알림 구독을 토글한다. [subscribed] 는 현재(토글 전) 상태.
  Future<void> toggleTeam(int teamId, bool subscribed) async {
    try {
      if (subscribed) {
        await _repo.unsubscribeTeam(teamId);
      } else {
        await _repo.subscribeTeam(teamId);
      }
      _availableTeams = [
        for (final t in _availableTeams)
          t.teamId == teamId ? t.copyWith(subscribed: !subscribed) : t,
      ];
      _notify();
    } catch (e) {
      debugPrint('[Subscription] toggleTeam 에러: $e');
    }
  }

  /// 선수 토글 결과를 구독중 목록·전체 목록 양쪽에 반영한다.
  void _applyPlayerToggle(int playerId, bool nowSubscribed) {
    _availablePlayers = [
      for (final p in _availablePlayers)
        p.playerId == playerId ? p.copyWith(subscribed: nowSubscribed) : p,
    ];
    if (nowSubscribed) {
      if (!_subscribedPlayers.any((p) => p.playerId == playerId)) {
        final added = _availablePlayers
            .firstWhere((p) => p.playerId == playerId)
            .copyWith(subscribed: true);
        _subscribedPlayers = [..._subscribedPlayers, added];
      }
    } else {
      _subscribedPlayers =
          _subscribedPlayers.where((p) => p.playerId != playerId).toList();
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
