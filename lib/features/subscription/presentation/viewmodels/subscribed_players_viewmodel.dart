import 'package:flutter/foundation.dart';

import 'package:warding/core/di_container.dart';
import 'package:warding/core/error/failure_exception.dart';
import 'package:warding/core/infrastructure/auth/auth_service.dart';
import 'package:warding/domain/player_subscription.dart';
import 'package:warding/features/subscription/domain/repositories/subscription_repository.dart';

/// 내가 구독한 선수 목록.
///
/// 솔랭 카드([SoloRankViewModel])와 쇼츠 팀 매칭이 이 목록을 쓴다 — 홈 전용이
/// 아니라 구독 기능이 소유한다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
class SubscribedPlayersViewModel extends ChangeNotifier {
  SubscribedPlayersViewModel({
    SubscriptionRepository? repository,
    AuthService? auth,
  }) : _repository = repository ?? di<SubscriptionRepository>(),
       _auth = auth ?? AuthService.instance;

  final SubscriptionRepository _repository;
  final AuthService _auth;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 실제 구독 선수 목록. null 이면 아직 못 받았거나 비회원·실패 —
  /// 이때 구독 수는 0명으로 본다.
  List<PlayerSubscription>? _players;
  List<PlayerSubscription>? get players => _players;

  /// 구독 수 — 실제 목록 길이만 센다. 비회원(JWT 없음)이나 조회 실패는 0명이다.
  int get total => _players?.length ?? 0;

  /// 첫 조회가 아직 끝나지 않았는지. 성공·실패·비회원 어느 쪽으로든 한 번
  /// 끝나면 계속 false 다(이후 새로고침은 이 값에 영향 없음) — 앱 복귀
  /// 새로고침마다 스켈레톤이 다시 뜨는 걸 막는다.
  bool _firstLoadPending = true;
  bool get loading => _firstLoadPending;

  int _gen = 0;

  Future<void> load() async {
    final gen = ++_gen;
    try {
      // 비회원(JWT 없음)이면 authorizedRequest 가 던진다 → 아래 catch.
      final players = (await _repository.fetchSubscribedPlayers())
          .getOrElse((f) => throw FailureException(f));
      // 그 사이 더 새 요청이 떴으면 옛 응답은 버린다.
      if (_disposed || gen != _gen) return;
      _players = players;
      _firstLoadPending = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[SubscribedPlayers] 구독 선수 조회 실패(비회원 포함): $e');
      if (_disposed || gen != _gen) return;
      _firstLoadPending = false;
      // 로그아웃했으면 이전 계정의 구독 선수를 붙들고 있지 않는다(그 밖의
      // 실패는 마지막 값을 유지한다).
      if (_players != null && await _signedOut()) {
        if (_disposed || gen != _gen) return;
        _players = null;
      }
      notifyListeners();
    }
  }

  Future<bool> _signedOut() async {
    try {
      return await _auth.jwt == null;
    } catch (_) {
      return false; // Keychain 을 못 읽은 건 로그아웃이 아니다.
    }
  }
}
