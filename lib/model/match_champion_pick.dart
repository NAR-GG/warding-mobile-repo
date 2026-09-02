import '../util/champion_image.dart';

/// 경기 상세 — 챔피언 픽 탭의 양 팀 밴·픽 데이터.
///
/// `GET /api/mobile/live/games/{gameId}/champions` 응답에 대응한다.
class MatchChampionPick {
  const MatchChampionPick({
    required this.gameId,
    required this.blueTeam,
    required this.redTeam,
    required this.objectives,
  });

  final String gameId;
  final ChampionTeam blueTeam;
  final ChampionTeam redTeam;
  final MatchObjectives objectives;

  factory MatchChampionPick.fromJson(Map<String, dynamic> json) {
    return MatchChampionPick(
      gameId: json['gameId'] as String? ?? '',
      blueTeam: ChampionTeam.fromJson(
        json['blueTeam'] as Map<String, dynamic>? ?? const {},
      ),
      redTeam: ChampionTeam.fromJson(
        json['redTeam'] as Map<String, dynamic>? ?? const {},
      ),
      objectives: MatchObjectives.fromJson(
        json['objectives'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// 양 팀의 오브젝트(드래곤·바론·타워·억제기) 집계.
class MatchObjectives {
  const MatchObjectives({required this.blueTeam, required this.redTeam});

  final TeamObjectives blueTeam;
  final TeamObjectives redTeam;

  factory MatchObjectives.fromJson(Map<String, dynamic> json) {
    return MatchObjectives(
      blueTeam: TeamObjectives.fromJson(
        json['blueTeam'] as Map<String, dynamic>? ?? const {},
      ),
      redTeam: TeamObjectives.fromJson(
        json['redTeam'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// 한 팀의 오브젝트 집계.
class TeamObjectives {
  const TeamObjectives({
    this.dragons = 0,
    this.dragonTypes = const [],
    this.elders = 0,
    this.barons = 0,
    this.towers = 0,
    this.inhibitors = 0,
  });

  final int dragons;

  /// 드래곤 속성 한국어 라벨 목록 (먹은 순서). [dragonAssetFor] 로 아이콘 매핑.
  final List<String> dragonTypes;
  final int elders;
  final int barons;
  final int towers;
  final int inhibitors;

  factory TeamObjectives.fromJson(Map<String, dynamic> json) {
    return TeamObjectives(
      dragons: json['dragons'] as int? ?? 0,
      dragonTypes: (json['dragonTypes'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      elders: json['elders'] as int? ?? 0,
      barons: json['barons'] as int? ?? 0,
      towers: json['towers'] as int? ?? 0,
      inhibitors: json['inhibitors'] as int? ?? 0,
    );
  }
}

/// 한 팀의 밴·픽.
class ChampionTeam {
  const ChampionTeam({
    required this.teamName,
    required this.picks,
    required this.bans,
    required this.summary,
  });

  final String teamName;
  final List<ChampionPick> picks;
  final List<ChampionBan> bans;
  final TeamStatsSummary summary;

  factory ChampionTeam.fromJson(Map<String, dynamic> json) {
    return ChampionTeam(
      teamName: json['teamName'] as String? ?? '',
      picks: (json['picks'] as List<dynamic>? ?? const [])
          .map((e) => ChampionPick.fromJson(e as Map<String, dynamic>))
          .toList(),
      bans: (json['bans'] as List<dynamic>? ?? const [])
          .map((e) => ChampionBan.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: TeamStatsSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
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

/// 픽된 챔피언 한 건. 라이브 스코어보드(KDA·CS·골드·아이템·룬)를 포함한다.
class ChampionPick {
  const ChampionPick({
    required this.position,
    required this.championName,
    required this.playerName,
    this.championImageUrl,
    this.level = 0,
    this.kills = 0,
    this.deaths = 0,
    this.assists = 0,
    this.creepScore = 0,
    this.totalGoldEarned = 0,
    this.killParticipation = 0,
    this.championDamageShare = 0,
    this.itemImageUrls = const [],
    this.keystoneIconUrl,
    this.subStyleIconUrl,
  });

  final String position;
  final String championName;
  final String playerName;
  final String? championImageUrl;

  final int level;
  final int kills;
  final int deaths;
  final int assists;
  final int creepScore;
  final int totalGoldEarned;

  /// 0.0~1.0 비율. 화면 표시는 `(killParticipation * 100).round()`.
  final double killParticipation;

  /// 0.0~1.0 비율.
  final double championDamageShare;

  /// 구매한 아이템 이미지 URL 목록. 순서대로, 개수는 가변(빈 슬롯은 미포함).
  final List<String> itemImageUrls;

  final String? keystoneIconUrl;
  final String? subStyleIconUrl;

  /// 표시용 이미지 URL (백엔드 값 없으면 Data Dragon 폴백).
  String? get imageUrl =>
      ChampionImage.resolve(championImageUrl, championName);

  factory ChampionPick.fromJson(Map<String, dynamic> json) {
    return ChampionPick(
      position: json['position'] as String? ?? '',
      championName: json['championName'] as String? ?? '',
      playerName: json['playerName'] as String? ?? '',
      championImageUrl: json['championImageUrl'] as String?,
      level: json['level'] as int? ?? 0,
      kills: json['kills'] as int? ?? 0,
      deaths: json['deaths'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
      creepScore: json['creepScore'] as int? ?? 0,
      totalGoldEarned: json['totalGoldEarned'] as int? ?? 0,
      killParticipation: (json['killParticipation'] as num?)?.toDouble() ?? 0,
      championDamageShare:
          (json['championDamageShare'] as num?)?.toDouble() ?? 0,
      itemImageUrls: (json['itemImageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      keystoneIconUrl: json['keystoneIconUrl'] as String?,
      subStyleIconUrl: json['subStyleIconUrl'] as String?,
    );
  }
}

/// 팀 합산 스코어(K/D/A·CS·골드·와드).
class TeamStatsSummary {
  const TeamStatsSummary({
    this.kills = 0,
    this.deaths = 0,
    this.assists = 0,
    this.creepScore = 0,
    this.totalGoldEarned = 0,
    this.wardsPlaced = 0,
    this.wardsKilled = 0,
  });

  final int kills;
  final int deaths;
  final int assists;
  final int creepScore;
  final int totalGoldEarned;

  /// 와드 설치 수. CH 확인상 시야점수(vision score) 자체는 없지만 이 값은
  /// 가능하다고 함 — 백엔드 응답에 아직 없어 필드명이 미확정이다. 스펙이
  /// 확정되면 `wardsPlaced`/`wardsKilled` 이름과 json 키를 실제 값으로
  /// 맞춰야 한다(지금은 항상 0).
  final int wardsPlaced;

  /// 와드 파괴 수. [wardsPlaced] 와 같은 이유로 미확정.
  final int wardsKilled;

  factory TeamStatsSummary.fromJson(Map<String, dynamic> json) {
    return TeamStatsSummary(
      kills: json['kills'] as int? ?? 0,
      deaths: json['deaths'] as int? ?? 0,
      assists: json['assists'] as int? ?? 0,
      creepScore: json['creepScore'] as int? ?? 0,
      totalGoldEarned: json['totalGoldEarned'] as int? ?? 0,
      wardsPlaced: json['wardsPlaced'] as int? ?? 0,
      wardsKilled: json['wardsKilled'] as int? ?? 0,
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
