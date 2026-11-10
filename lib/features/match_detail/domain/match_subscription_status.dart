/// 경기 한 건의 예약 구독·알림 토글 상태.
///
/// `GET /api/mobile/me/match-subscriptions/{matchId}` 응답에 대응한다.
/// 구독 중이 아니면 서버가 [subscribed] = false 와 기본값(전부 true)을 돌려주므로,
/// 알림 설정 시트를 신규 등록으로 열지 수정으로 열지는 [subscribed] 로 가른다.
class MatchSubscriptionStatus {
  const MatchSubscriptionStatus({
    required this.matchId,
    required this.subscribed,
    required this.setStartEnabled,
    required this.setEndEnabled,
    required this.liveEventEnabled,
    required this.killEnabled,
    required this.baronEnabled,
    required this.dragonEnabled,
    required this.towerEnabled,
    required this.inhibitorEnabled,
  });

  final String matchId;
  final bool subscribed;

  final bool setStartEnabled;
  final bool setEndEnabled;
  final bool liveEventEnabled;

  // 라이브 이벤트 세부 5종. liveEventEnabled 가 false 면 서버가 쓰지 않는다.
  final bool killEnabled;
  final bool baronEnabled;
  final bool dragonEnabled;
  final bool towerEnabled;
  final bool inhibitorEnabled;

  factory MatchSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    // 누락 필드는 켜짐으로 본다 — 서버 기본값이 전부 true 다.
    bool flag(String key) => json[key] as bool? ?? true;
    return MatchSubscriptionStatus(
      matchId: json['matchId'] as String? ?? '',
      subscribed: json['subscribed'] as bool? ?? false,
      setStartEnabled: flag('setStartEnabled'),
      setEndEnabled: flag('setEndEnabled'),
      liveEventEnabled: flag('liveEventEnabled'),
      killEnabled: flag('killEnabled'),
      baronEnabled: flag('baronEnabled'),
      dragonEnabled: flag('dragonEnabled'),
      towerEnabled: flag('towerEnabled'),
      inhibitorEnabled: flag('inhibitorEnabled'),
    );
  }
}
