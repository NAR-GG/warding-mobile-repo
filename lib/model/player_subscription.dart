/// 구독 가능/구독중 선수 한 명.
///
/// `/api/mobile/me/player-subscriptions` 계열 응답 항목에 대응한다.
/// 선수 본인 정보와 소속 팀 정보, 그리고 현재 구독 여부([subscribed])를 담는다.
class PlayerSubscription {
  const PlayerSubscription({
    required this.playerId,
    required this.playerName,
    required this.playerImageUrl,
    required this.role,
    required this.teamId,
    required this.teamCode,
    required this.teamName,
    required this.teamImageUrl,
    required this.subscribed,
    required this.startEnabled,
    required this.endEnabled,
  });

  final int playerId;
  final String playerName;
  final String playerImageUrl;

  /// 포지션. 예: 'TOP', 'MID'.
  final String role;

  final int teamId;
  final String teamCode;
  final String teamName;
  final String teamImageUrl;

  /// 현재 사용자가 이 선수를 구독 중인지.
  final bool subscribed;

  /// 솔랭 시작 알림 ON/OFF.
  final bool startEnabled;

  /// 솔랭 종료 알림 ON/OFF.
  final bool endEnabled;

  /// 일부 값만 바꾼 복사본 — 토글 직후 로컬 상태 갱신에 쓴다.
  PlayerSubscription copyWith({
    bool? subscribed,
    bool? startEnabled,
    bool? endEnabled,
  }) {
    return PlayerSubscription(
      playerId: playerId,
      playerName: playerName,
      playerImageUrl: playerImageUrl,
      role: role,
      teamId: teamId,
      teamCode: teamCode,
      teamName: teamName,
      teamImageUrl: teamImageUrl,
      subscribed: subscribed ?? this.subscribed,
      startEnabled: startEnabled ?? this.startEnabled,
      endEnabled: endEnabled ?? this.endEnabled,
    );
  }

  factory PlayerSubscription.fromJson(Map<String, dynamic> json) {
    return PlayerSubscription(
      playerId: json['playerId'] as int? ?? 0,
      playerName: json['playerName'] as String? ?? '',
      playerImageUrl: json['playerImageUrl'] as String? ?? '',
      role: json['role'] as String? ?? '',
      teamId: json['teamId'] as int? ?? 0,
      teamCode: json['teamCode'] as String? ?? '',
      teamName: json['teamName'] as String? ?? '',
      teamImageUrl: json['teamImageUrl'] as String? ?? '',
      subscribed: json['subscribed'] as bool? ?? false,
      startEnabled: json['startEnabled'] as bool? ?? true,
      endEnabled: json['endEnabled'] as bool? ?? true,
    );
  }
}

/// 구독 가능 선수 검색의 페이지 결과.
///
/// `/api/mobile/me/player-subscriptions/available-players` 응답에 대응한다.
class PlayerPage {
  const PlayerPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<PlayerSubscription> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  /// 다음 페이지가 더 있는지.
  bool get hasMore => page + 1 < totalPages;

  factory PlayerPage.fromJson(Map<String, dynamic> json) {
    return PlayerPage(
      content: (json['content'] as List<dynamic>? ?? const [])
          .map((e) => PlayerSubscription.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}
