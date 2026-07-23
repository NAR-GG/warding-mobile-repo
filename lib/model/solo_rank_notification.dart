import '../l10n/app_strings.dart';

/// 수신한 '선수 솔랭 시작' 푸시 한 건.
///
/// FCM data 페이로드(모두 String)에서 파싱하며, 마이구독 피드에 표시하기 위해
/// 기기에 로컬 저장한다(서버 알림 기록 API 없음). [receivedAt] 은 수신 시각.
class SoloRankNotification {
  const SoloRankNotification({
    required this.playerId,
    required this.playerName,
    required this.championName,
    required this.queueType,
    required this.gameId,
    required this.receivedAt,
    this.opggUrl,
    this.championImageUrl,
  });

  final String playerId;
  final String playerName;
  final String championName;
  final String queueType;
  final String gameId;
  final DateTime receivedAt;
  final String? opggUrl;
  final String? championImageUrl;

  /// 백엔드가 보낸 FCM data 페이로드에서 만든다.
  /// 백엔드 키: type/playerId/playerName/gameId/championName/queueType/opggUrl/championImageUrl.
  factory SoloRankNotification.fromFcmData(
    Map<String, dynamic> data, {
    DateTime? receivedAt,
  }) {
    String s(String key) => (data[key] ?? '').toString();
    String? sn(String key) {
      final v = data[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    return SoloRankNotification(
      playerId: s('playerId'),
      playerName: s('playerName').isEmpty ? (appStrings?.fallbackPlayer ?? 'Player') : s('playerName'),
      championName: s('championName').isEmpty ? (appStrings?.fallbackChampionInfo ?? 'Loading champion info') : s('championName'),
      queueType: s('queueType').isEmpty ? (appStrings?.soloRank ?? 'Solo Rank') : s('queueType'),
      gameId: s('gameId'),
      opggUrl: sn('opggUrl'),
      championImageUrl: sn('championImageUrl'),
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  /// 같은 게임의 중복 저장을 막기 위한 키.
  String get dedupeKey => '$playerId:$gameId';

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'championName': championName,
        'queueType': queueType,
        'gameId': gameId,
        'opggUrl': opggUrl,
        'championImageUrl': championImageUrl,
        'receivedAt': receivedAt.toIso8601String(),
      };

  factory SoloRankNotification.fromJson(Map<String, dynamic> json) {
    return SoloRankNotification(
      playerId: (json['playerId'] ?? '').toString(),
      playerName: (json['playerName'] as String?)?.isNotEmpty == true
          ? json['playerName'] as String
          : (appStrings?.fallbackPlayer ?? 'Player'),
      championName: (json['championName'] ?? '').toString(),
      queueType: (json['queueType'] as String?)?.isNotEmpty == true
          ? json['queueType'] as String
          : (appStrings?.soloRank ?? 'Solo Rank'),
      gameId: (json['gameId'] ?? '').toString(),
      opggUrl: json['opggUrl'] as String?,
      championImageUrl: json['championImageUrl'] as String?,
      receivedAt:
          DateTime.tryParse(json['receivedAt']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}
