import '../l10n/app_strings.dart';

/// 마이구독 알림 피드 한 건.
///
/// `GET /api/mobile/me/notifications` 응답 항목에 대응한다. 백엔드가 푸시 발송
/// 성공 시 적재한 알림을 최신순으로 돌려준다. [data] 는 FCM 페이로드를 그대로
/// 보존한 맵(deepLink/playerId/matchId/setNumber 등, 값은 모두 String).
class MemberNotification {
  const MemberNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  final int id;
  final MemberNotificationType type;
  final String title;
  final String body;
  final Map<String, String> data;
  final bool read;
  final DateTime createdAt;

  // ── data 맵 편의 접근자 ──────────────────────────────────────────
  String? _d(String key) {
    final v = data[key];
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 딥링크(예: 'nar://players/42'). 솔랭 알림에만 존재.
  String? get deepLink => _d('deepLink');

  /// 경기 식별자. 팀 이벤트(세트 시작·종료·라이브) 탭 시 경기 상세로 이동에 쓴다.
  String? get matchId => _d('matchId');

  // 솔랭 카드 재구성용 — 서버 data 에 모두 들어있다.
  String get playerName => _d('playerName') ?? (appStrings?.fallbackPlayer ?? 'Player');
  String get championName => _d('championName') ?? (appStrings?.fallbackChampionInfo ?? 'Loading champion info');
  String get queueType => _d('queueType') ?? (appStrings?.soloRank ?? 'Solo Rank');
  String? get championImageUrl => _d('championImageUrl');
  String? get opggUrl => _d('opggUrl');

  // ── 솔랭 시작/종료 구분 ────────────────────────────────────────
  // `type` 은 시작·종료 모두 PLAYER_SOLO_RANK_STARTED 다(앱 딥링크 라우팅 키라
  // 서버가 바꾸지 않는다). 구분은 오직 data.eventType 으로 한다.

  /// 솔랭 **종료** 알림인가. 시작 알림이면 false.
  bool get isSoloRankEnd => _d('eventType') == 'END';

  /// 승패. 종료 알림이라도 match-v5 결과를 못 읽었으면 키 자체가 없어 null.
  bool? get soloRankWin => switch (_d('win')) {
        'true' => true,
        'false' => false,
        _ => null,
      };

  /// 'K/D/A' 문자열(예: '18/1/11'). 셋 다 있을 때만 서버가 실어준다.
  String? get kda => _d('kda');

  MemberNotification copyWith({bool? read}) => MemberNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  factory MemberNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = <String, String>{};
    if (rawData is Map) {
      rawData.forEach((k, v) {
        if (v != null) data[k.toString()] = v.toString();
      });
    }
    return MemberNotification(
      id: json['id'] as int? ?? 0,
      type: MemberNotificationType.fromApi(json['type'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: data,
      read: json['read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime(1970),
    );
  }
}

/// 알림 종류. 백엔드 enum(`MemberNotificationType`) 과 1:1.
enum MemberNotificationType {
  setStart,
  setEnd,
  liveEvent,
  playerSoloRank,
  unknown;

  static MemberNotificationType fromApi(String? s) {
    switch (s) {
      case 'SET_START':
        return setStart;
      case 'SET_END':
        return setEnd;
      case 'LIVE_EVENT':
        return liveEvent;
      case 'PLAYER_SOLO_RANK_STARTED':
        return playerSoloRank;
      default:
        return unknown;
    }
  }
}

/// 알림 리스트 페이지 결과 + 미읽음 수.
class MemberNotificationPage {
  const MemberNotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<MemberNotification> notifications;

  /// 필터와 무관한 전체 기준 미읽음 수.
  final int unreadCount;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get hasMore => page + 1 < totalPages;

  factory MemberNotificationPage.fromJson(Map<String, dynamic> json) {
    return MemberNotificationPage(
      notifications: (json['notifications'] as List<dynamic>? ?? const [])
          .map((e) => MemberNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}
