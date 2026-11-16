import 'package:flutter/foundation.dart';

import 'package:warding/app/di_container.dart';
import 'package:warding/core/error/failure_exception.dart';
import 'package:warding/features/auth/data/auth_service.dart';
import 'package:warding/features/match_detail/domain/repositories/match_subscription_repository.dart';

/// 경기 카드의 알림 벨 하나의 구독 상태.
///
/// 벨이 카드마다 하나씩이라 ViewModel 도 카드마다 만든다 — 목록 전체의 구독
/// 상태를 한 곳에 모으려면 카드가 그 목록을 알아야 해서 결합이 커진다.
///
/// 비회원은 조회하지 않고 미구독으로 둔다. 조회 실패도 미구독이다 — 벨은
/// 눌러야 알 수 있는 값이 아니라 눌러서 바꾸는 값이라, 틀려도 탭 한 번으로
/// 교정된다.
///
/// 생성자는 조회하지 않는다. 첫 로드 시점은 쓰는 쪽이 [load] 로 정한다.
class MatchAlarmBellViewModel extends ChangeNotifier {
  MatchAlarmBellViewModel({
    required this.matchId,
    MatchSubscriptionRepository? repository,
    AuthService? auth,
  }) : _repository = repository ?? di<MatchSubscriptionRepository>(),
       _auth = auth ?? AuthService.instance;

  final String matchId;
  final MatchSubscriptionRepository _repository;
  final AuthService _auth;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _subscribed = false;
  bool get subscribed => _subscribed;

  /// 서버 구독 목록에서 이 경기가 있는지 확인한다.
  Future<void> load() async {
    try {
      final jwt = await _auth.jwt;
      if (jwt == null || jwt.isEmpty) return; // 비회원은 정적 상태로 둔다.
      final ids = (await _repository.subscribedMatchIds())
          .getOrElse((f) => throw FailureException(f));
      if (_disposed) return;
      final next = ids.contains(matchId);
      if (next == _subscribed) return;
      _subscribed = next;
      notifyListeners();
    } catch (_) {
      // 조회 실패 시 기본값(미구독) 유지.
    }
  }

  /// 알림 시트가 돌려준 결과를 반영한다.
  void applyResult({required bool subscribed}) {
    if (_disposed || subscribed == _subscribed) return;
    _subscribed = subscribed;
    notifyListeners();
  }
}
