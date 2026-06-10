/// 팀 알림 구독 한 건.
///
/// `/api/mobile/me/notification-subscriptions` 계열 응답 항목에 대응한다.
/// 팀 정보와 구독 여부, 그리고 세트 시작/종료·라이브 이벤트 알림 ON/OFF 를 담는다.
class TeamNotificationSubscription {
  const TeamNotificationSubscription({
    required this.teamId,
    required this.teamCode,
    required this.teamName,
    required this.teamImageUrl,
    required this.favoriteTeam,
    required this.subscribed,
    required this.setStartEnabled,
    required this.setEndEnabled,
    required this.liveEventEnabled,
  });

  final int teamId;
  final String teamCode;
  final String teamName;
  final String teamImageUrl;

  /// 온보딩에서 고른 선호 팀인지.
  final bool favoriteTeam;

  /// 현재 사용자가 이 팀 알림을 구독 중인지.
  final bool subscribed;

  /// 세트 시작 알림 ON/OFF.
  final bool setStartEnabled;

  /// 세트 종료 알림 ON/OFF.
  final bool setEndEnabled;

  /// 라이브 이벤트 알림 ON/OFF.
  final bool liveEventEnabled;

  /// 일부 값만 바꾼 복사본 — 토글 직후 로컬 상태 갱신에 쓴다.
  TeamNotificationSubscription copyWith({
    bool? subscribed,
    bool? setStartEnabled,
    bool? setEndEnabled,
    bool? liveEventEnabled,
  }) {
    return TeamNotificationSubscription(
      teamId: teamId,
      teamCode: teamCode,
      teamName: teamName,
      teamImageUrl: teamImageUrl,
      favoriteTeam: favoriteTeam,
      subscribed: subscribed ?? this.subscribed,
      setStartEnabled: setStartEnabled ?? this.setStartEnabled,
      setEndEnabled: setEndEnabled ?? this.setEndEnabled,
      liveEventEnabled: liveEventEnabled ?? this.liveEventEnabled,
    );
  }

  factory TeamNotificationSubscription.fromJson(Map<String, dynamic> json) {
    return TeamNotificationSubscription(
      teamId: json['teamId'] as int? ?? 0,
      teamCode: json['teamCode'] as String? ?? '',
      teamName: json['teamName'] as String? ?? '',
      teamImageUrl: json['teamImageUrl'] as String? ?? '',
      favoriteTeam: json['favoriteTeam'] as bool? ?? false,
      subscribed: json['subscribed'] as bool? ?? false,
      setStartEnabled: json['setStartEnabled'] as bool? ?? false,
      setEndEnabled: json['setEndEnabled'] as bool? ?? false,
      liveEventEnabled: json['liveEventEnabled'] as bool? ?? false,
    );
  }
}
