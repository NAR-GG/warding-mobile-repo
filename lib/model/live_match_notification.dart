import '../l10n/app_strings.dart';

/// 수신한 '라이브 경기' 푸시 한 건(세트 시작/종료/경기 이벤트).
///
/// 솔랭 알림([SoloRankNotification])과 달리 선수/챔피언 필드가 없고,
/// 경기 식별자([matchId])와 푸시의 제목/본문을 그대로 들고 있다.
/// 서버 알림 기록 API가 없어 기기에 로컬 저장한다. [receivedAt] 은 수신 시각.
class LiveMatchNotification {
  const LiveMatchNotification({
    required this.type,
    required this.matchId,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.setNumber,
  });

  /// 푸시 타입(SET_START / SET_END / LIVE_EVENT).
  final String type;

  /// 경기 ID. 딥링크(경기 상세 '라이브 이벤트' 탭)의 기준.
  final String matchId;

  /// 푸시 제목(notification.title 또는 data['title']).
  final String title;

  /// 푸시 본문(notification.body 또는 data['body']).
  final String body;

  /// 세트 번호(있으면). 없으면 null.
  final String? setNumber;

  final DateTime receivedAt;

  /// 백엔드가 보낸 FCM data 페이로드에서 만든다.
  /// 키: type / matchId / setNumber(opt). 제목·본문은 data 에 없으면
  /// notification 페이로드에서 받은 값을 [title]/[body] 로 넘긴다.
  factory LiveMatchNotification.fromFcmData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    DateTime? receivedAt,
  }) {
    String s(String key) => (data[key] ?? '').toString();
    String? sn(String key) {
      final v = data[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    return LiveMatchNotification(
      type: s('type'),
      matchId: s('matchId'),
      title: (title ?? sn('title') ?? (appStrings?.liveMatchNotification ?? 'Live Match Notification')),
      body: (body ?? sn('body') ?? ''),
      setNumber: sn('setNumber'),
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  /// 중복 저장을 막기 위한 키. 같은 경기·세트·타입이면 같은 알림으로 본다.
  String get dedupeKey => '$matchId:${setNumber ?? '-'}:$type';

  Map<String, dynamic> toJson() => {
        'type': type,
        'matchId': matchId,
        'title': title,
        'body': body,
        'setNumber': setNumber,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory LiveMatchNotification.fromJson(Map<String, dynamic> json) {
    return LiveMatchNotification(
      type: (json['type'] ?? '').toString(),
      matchId: (json['matchId'] ?? '').toString(),
      title: (json['title'] as String?)?.isNotEmpty == true
          ? json['title'] as String
          : (appStrings?.liveMatchNotification ?? 'Live Match Notification'),
      body: (json['body'] ?? '').toString(),
      setNumber: json['setNumber'] as String?,
      receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
