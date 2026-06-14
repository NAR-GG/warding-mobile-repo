import '../util/champion_image.dart';

/// 경기 상세 — 챔피언 픽 탭의 양 팀 밴·픽 데이터.
///
/// `GET /api/mobile/live/games/{gameId}/champions` 응답에 대응한다.
class MatchChampionPick {
  const MatchChampionPick({
    required this.gameId,
    required this.blueTeam,
    required this.redTeam,
  });

  final String gameId;
  final ChampionTeam blueTeam;
  final ChampionTeam redTeam;

  factory MatchChampionPick.fromJson(Map<String, dynamic> json) {
    return MatchChampionPick(
      gameId: json['gameId'] as String? ?? '',
      blueTeam: ChampionTeam.fromJson(
        json['blueTeam'] as Map<String, dynamic>? ?? const {},
      ),
      redTeam: ChampionTeam.fromJson(
        json['redTeam'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// 한 팀의 밴·픽.
class ChampionTeam {
  const ChampionTeam({
    required this.teamName,
    required this.picks,
    required this.bans,
  });

  final String teamName;
  final List<ChampionPick> picks;
  final List<ChampionBan> bans;

  factory ChampionTeam.fromJson(Map<String, dynamic> json) {
    return ChampionTeam(
      teamName: json['teamName'] as String? ?? '',
      picks: (json['picks'] as List<dynamic>? ?? const [])
          .map((e) => ChampionPick.fromJson(e as Map<String, dynamic>))
          .toList(),
      bans: (json['bans'] as List<dynamic>? ?? const [])
          .map((e) => ChampionBan.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 챔피언 이미지 URL 5개 (픽 순서대로, 폴백 적용). 부족하면 null 로 패딩.
  List<String?> pickImageUrls() => _padTo5(
        picks.map((p) => p.imageUrl).toList(),
      );

  /// 픽 선수명 5개 (픽 순서대로). 부족하면 빈 문자열로 패딩.
  List<String> pickPlayerNames() {
    final names = picks.map((p) => p.playerName).toList();
    while (names.length < 5) {
      names.add('');
    }
    return names.take(5).toList();
  }

  /// 밴 챔피언 이미지 URL 5개 (폴백 적용). 부족하면 null 로 패딩.
  List<String?> banImageUrls() => _padTo5(
        bans.map((b) => b.imageUrl).toList(),
      );

  static List<String?> _padTo5(List<String?> list) {
    final out = List<String?>.from(list);
    while (out.length < 5) {
      out.add(null);
    }
    return out.take(5).toList();
  }
}

/// 픽된 챔피언 한 건.
class ChampionPick {
  const ChampionPick({
    required this.position,
    required this.championName,
    required this.playerName,
    this.championImageUrl,
  });

  final String position;
  final String championName;
  final String playerName;
  final String? championImageUrl;

  /// 표시용 이미지 URL (백엔드 값 없으면 Data Dragon 폴백).
  String? get imageUrl =>
      ChampionImage.resolve(championImageUrl, championName);

  factory ChampionPick.fromJson(Map<String, dynamic> json) {
    return ChampionPick(
      position: json['position'] as String? ?? '',
      championName: json['championName'] as String? ?? '',
      playerName: json['playerName'] as String? ?? '',
      championImageUrl: json['championImageUrl'] as String?,
    );
  }
}

/// 밴된 챔피언 한 건.
class ChampionBan {
  const ChampionBan({
    required this.championName,
    this.championImageUrl,
  });

  final String championName;
  final String? championImageUrl;

  String? get imageUrl =>
      ChampionImage.resolve(championImageUrl, championName);

  factory ChampionBan.fromJson(Map<String, dynamic> json) {
    return ChampionBan(
      championName: json['championName'] as String? ?? '',
      championImageUrl: json['championImageUrl'] as String?,
    );
  }
}
