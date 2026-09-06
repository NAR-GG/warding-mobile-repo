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
    this.frameTimestampUtc,
  });

  final String gameId;
  final ChampionTeam blueTeam;
  final ChampionTeam redTeam;
  final MatchObjectives objectives;

  /// 이 응답이 기준한 프레임 시각(UTC, 타임존 접미 없음). #526 부터 내려온다.
  final String? frameTimestampUtc;

  factory MatchChampionPick.fromJson(Map<String, dynamic> json) {
    return MatchChampionPick(
      gameId: json['gameId'] as String? ?? '',
      frameTimestampUtc: json['frameTimestampUtc'] as String?,
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
  List<String?> pickImageUrls() =>
      _padTo5(picks.map((p) => p.imageUrl).toList());

  /// 픽 선수명 5개 (픽 순서대로). 부족하면 빈 문자열로 패딩.
  List<String> pickPlayerNames() {
    final names = picks.map((p) => p.playerName).toList();
    while (names.length < 5) {
      names.add('');
    }
    return names.take(5).toList();
  }

  /// 밴 챔피언 이미지 URL 5개 (폴백 적용). 부족하면 null 로 패딩.
  List<String?> banImageUrls() => _padTo5(bans.map((b) => b.imageUrl).toList());

  /// [summary] 에 5명 [picks] 의 와드 설치·파괴 합산을 채워 반환한다.
  /// `summary`(TeamSummary) 스키마 자체엔 와드 필드가 없어(항상 0) 팀
  /// 단위로는 못 주지만, 각 [ChampionPick] 에는 선수별 와드 값이 내려온다.
  TeamStatsSummary get summaryWithWards {
    var placed = 0;
    var killed = 0;
    for (final p in picks) {
      placed += p.wardsPlaced;
      killed += p.wardsDestroyed;
    }
    return summary.copyWith(wardsPlaced: placed, wardsKilled: killed);
  }

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
    this.wardsPlaced = 0,
    this.wardsDestroyed = 0,
    this.itemImageUrls = const [],
    this.coreItemImageUrls = const [],
    this.questItemImageUrl,
    this.trinketItemImageUrl,
    this.consumableItemImageUrls = const [],
    this.keystoneIconUrl,
    this.subStyleIconUrl,
    this.runes,
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

  /// 이 선수의 와드 설치·파괴 수. #? 부터 champions API(Pick)에 직접
  /// 내려온다 — 팀 합산은 [ChampionTeam.summaryWithWards] 가 5명분을 더한다.
  final int wardsPlaced;
  final int wardsDestroyed;

  /// 0.0~1.0 비율. 화면 표시는 `(killParticipation * 100).round()`.
  final double killParticipation;

  /// 0.0~1.0 비율.
  final double championDamageShare;

  /// 구매 순서 그대로의 원본 평면 배열(장신구 섞임). 호환용으로만 남아있다 —
  /// 화면 렌더링에는 [coreItemImageUrls]/[questItemImageUrl]/
  /// [trinketItemImageUrl]을 쓸 것.
  final List<String> itemImageUrls;

  /// 코어 아이템(장신구·소모품 제외). 길이 0~6.
  final List<String> coreItemImageUrls;

  /// 2026 바텀 퀘스트 완료 시의 신발. 없으면 null.
  final String? questItemImageUrl;

  /// 장신구. 안 샀으면 null.
  final String? trinketItemImageUrl;

  /// 제어와드·물약·영약 등 소모품. 서포터 퀘스트 칸(제어와드)도 여기로 온다.
  final List<String> consumableItemImageUrls;

  final String? keystoneIconUrl;
  final String? subStyleIconUrl;

  /// 룬 전체(주 트리 4개·부 트리 2개·파편). 라이브 첫 프레임 전이면 null.
  final PlayerRunes? runes;

  /// 표시용 이미지 URL (백엔드 값 없으면 Data Dragon 폴백).
  String? get imageUrl => ChampionImage.resolve(championImageUrl, championName);

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
      wardsPlaced: json['wardsPlaced'] as int? ?? 0,
      wardsDestroyed: json['wardsDestroyed'] as int? ?? 0,
      itemImageUrls: (json['itemImageUrls'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      coreItemImageUrls:
          (json['coreItemImageUrls'] as List<dynamic>? ?? const [])
              .map((e) => e as String)
              .toList(),
      questItemImageUrl: json['questItemImageUrl'] as String?,
      trinketItemImageUrl: json['trinketItemImageUrl'] as String?,
      consumableItemImageUrls:
          (json['consumableItemImageUrls'] as List<dynamic>? ?? const [])
              .map((e) => e as String)
              .toList(),
      keystoneIconUrl: json['keystoneIconUrl'] as String?,
      subStyleIconUrl: json['subStyleIconUrl'] as String?,
      runes: json['runes'] == null
          ? null
          : PlayerRunes.fromJson(json['runes'] as Map<String, dynamic>),
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

  /// 팀 합산 와드 설치 수. `summary`(TeamSummary) 스키마 자체엔 이 필드가
  /// 없어 서버 JSON에선 항상 0 — [ChampionTeam.summaryWithWards] 가 5명의
  /// [ChampionPick.wardsPlaced] 를 더해 채운 값을 대신 쓴다.
  final int wardsPlaced;

  /// 팀 합산 와드 파괴 수. [wardsPlaced] 와 같은 이유로 서버 JSON에선 항상 0.
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

  TeamStatsSummary copyWith({int? wardsPlaced, int? wardsKilled}) {
    return TeamStatsSummary(
      kills: kills,
      deaths: deaths,
      assists: assists,
      creepScore: creepScore,
      totalGoldEarned: totalGoldEarned,
      wardsPlaced: wardsPlaced ?? this.wardsPlaced,
      wardsKilled: wardsKilled ?? this.wardsKilled,
    );
  }
}

/// 밴된 챔피언 한 건.
class ChampionBan {
  const ChampionBan({required this.championName, this.championImageUrl});

  final String championName;
  final String? championImageUrl;

  String? get imageUrl => ChampionImage.resolve(championImageUrl, championName);

  factory ChampionBan.fromJson(Map<String, dynamic> json) {
    return ChampionBan(
      championName: json['championName'] as String? ?? '',
      championImageUrl: json['championImageUrl'] as String?,
    );
  }
}

/// 선수 한 명의 룬 전체(주 트리·부 트리·파편).
class PlayerRunes {
  const PlayerRunes({
    required this.primary,
    required this.sub,
    this.shards = const [],
  });

  /// 주 트리. `runes[0]`이 키스톤.
  final RuneStyle primary;

  /// 부 트리.
  final RuneStyle sub;

  /// 파편 2~3개(가변). 같은 파편을 두 칸에 찍으면 피드가 하나로 합쳐 보낸다.
  final List<RuneShard> shards;

  factory PlayerRunes.fromJson(Map<String, dynamic> json) {
    return PlayerRunes(
      primary: RuneStyle.fromJson(
        json['primary'] as Map<String, dynamic>? ?? const {},
      ),
      sub: RuneStyle.fromJson(json['sub'] as Map<String, dynamic>? ?? const {}),
      shards: (json['shards'] as List<dynamic>? ?? const [])
          .map((e) => RuneShard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 룬 트리 하나(주 또는 부).
class RuneStyle {
  const RuneStyle({
    required this.styleName,
    this.styleIconUrl,
    this.runes = const [],
  });

  final String styleName;
  final String? styleIconUrl;
  final List<RuneEntry> runes;

  factory RuneStyle.fromJson(Map<String, dynamic> json) {
    return RuneStyle(
      styleName: json['styleName'] as String? ?? '',
      styleIconUrl: json['styleIconUrl'] as String?,
      runes: (json['runes'] as List<dynamic>? ?? const [])
          .map((e) => RuneEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 룬 한 개. [description]은 게임 클라이언트 룬 선택창의 짧은 설명(평문).
class RuneEntry {
  const RuneEntry({required this.name, this.iconUrl, this.description});

  final String name;
  final String? iconUrl;
  final String? description;

  factory RuneEntry.fromJson(Map<String, dynamic> json) {
    return RuneEntry(
      name: json['name'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// 능력치 파편 한 칸. 칩 텍스트는 `name + " " + label`(예: '적응형 능력치 +9').
/// [label]이 null이면(옛 파편) name만 쓴다.
class RuneShard {
  const RuneShard({required this.name, this.iconUrl, this.label});

  final String name;
  final String? iconUrl;
  final String? label;

  factory RuneShard.fromJson(Map<String, dynamic> json) {
    return RuneShard(
      name: json['name'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      label: json['label'] as String?,
    );
  }
}
