import '../repository/home/home_api_sources.dart' show parseServerTime;
import 'home_models.dart';

int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double? _double(Object? v) => (v as num?)?.toDouble();
List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in v as List<dynamic>? ?? const []) e as Map<String, dynamic>,
];

/// 선수 페이지 헤더·다음 경기·지표 줄 (`GET /api/mobile/players/{playerId}`).
class PlayerDetail {
  const PlayerDetail({
    required this.playerId,
    required this.playerName,
    required this.role,
    required this.teamCode,
    required this.subscribed,
    required this.stats,
    this.startEnabled = true,
    this.endEnabled = false,
    this.playerImageUrl,
    this.teamName = '',
    this.teamImageUrl,
    this.live,
    this.lastGame,
    this.nextMatch,
  });

  factory PlayerDetail.fromJson(Map<String, dynamic> j) {
    final live = j['live'] as Map<String, dynamic>?;
    final last = j['lastGame'] as Map<String, dynamic>?;
    final next = j['nextMatch'] as Map<String, dynamic>?;
    return PlayerDetail(
      playerId: _int(j['playerId']),
      playerName: j['playerName'] as String? ?? '',
      playerImageUrl: j['playerImageUrl'] as String?,
      role: j['role'] as String? ?? '',
      teamCode: j['teamCode'] as String? ?? '',
      teamName: j['teamName'] as String? ?? '',
      teamImageUrl: j['teamImageUrl'] as String?,
      subscribed: j['subscribed'] as bool? ?? false,
      startEnabled: j['startEnabled'] as bool? ?? true,
      endEnabled: j['endEnabled'] as bool? ?? false,
      live: live == null ? null : PlayerLive.fromJson(live),
      lastGame: last == null ? null : PlayerLastGame.fromJson(last),
      nextMatch: next == null ? null : PlayerNextMatch.fromJson(next),
      stats: PlayerStats.fromJson(
        j['stats'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final int playerId;
  final String playerName;
  final String? playerImageUrl;
  final String role;
  final String teamCode;
  final String teamName;
  final String? teamImageUrl;
  final bool subscribed;

  /// 솔랭 시작·종료 알림(구독 중일 때 의미). 서버 기본은 시작 ON·종료 OFF.
  final bool startEnabled;
  final bool endEnabled;

  /// 솔랭 중이 아니면 null — 큰 카드 대신 프로필 줄(⑧-2).
  final PlayerLive? live;
  final PlayerLastGame? lastGame;
  final PlayerNextMatch? nextMatch;
  final PlayerStats stats;

  PlayerDetail copyWith({
    bool? subscribed,
    bool? startEnabled,
    bool? endEnabled,
  }) => PlayerDetail(
    playerId: playerId,
    playerName: playerName,
    playerImageUrl: playerImageUrl,
    role: role,
    teamCode: teamCode,
    teamName: teamName,
    teamImageUrl: teamImageUrl,
    subscribed: subscribed ?? this.subscribed,
    startEnabled: startEnabled ?? this.startEnabled,
    endEnabled: endEnabled ?? this.endEnabled,
    live: live,
    lastGame: lastGame,
    nextMatch: nextMatch,
    stats: stats,
  );

  /// 홈 큰 카드([HomeSoloHeroCard])를 그대로 쓰려고 홈 모델로 옮긴다.
  HomeLiveSoloPlayer? get liveAsHome {
    final l = live;
    if (l == null) return null;
    final startedAt = l.startedAt;
    return HomeLiveSoloPlayer(
      name: playerName,
      teamCode: teamCode,
      champion: l.championName,
      elapsedSeconds: startedAt == null
          ? 0
          : DateTime.now().difference(startedAt).inSeconds.clamp(0, 1 << 30),
      playerImageUrl: playerImageUrl,
      championImageUrl: l.championImageUrl,
      startedAt: startedAt,
      playerId: playerId,
      cheerTotal: l.cheerTotal,
      cheerMine: l.cheerMine,
      platform: l.platform,
      teamImageUrl: teamImageUrl,
    );
  }
}

class PlayerLive {
  const PlayerLive({
    required this.championName,
    this.championImageUrl,
    this.startedAt,
    this.platform,
    this.cheerTotal = 0,
    this.cheerMine = 0,
  });

  factory PlayerLive.fromJson(Map<String, dynamic> j) => PlayerLive(
    championName: j['championName'] as String? ?? '',
    championImageUrl: j['championImageUrl'] as String?,
    startedAt: parseServerTime(j['startedAt']),
    platform: j['platform'] as String?,
    cheerTotal: _int(j['cheerTotal']),
    cheerMine: _int(j['cheerMine']),
  );

  final String championName;
  final String? championImageUrl;
  final DateTime? startedAt;
  final String? platform;
  final int cheerTotal;
  final int cheerMine;
}

class PlayerLastGame {
  const PlayerLastGame({
    required this.championName,
    required this.win,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.durationSeconds,
    this.championImageUrl,
    this.endedAt,
  });

  factory PlayerLastGame.fromJson(Map<String, dynamic> j) => PlayerLastGame(
    championName: j['championName'] as String? ?? '',
    championImageUrl: j['championImageUrl'] as String?,
    win: j['win'] as bool? ?? false,
    kills: _int(j['kills']),
    deaths: _int(j['deaths']),
    assists: _int(j['assists']),
    durationSeconds: _int(j['durationSeconds']),
    endedAt: parseServerTime(j['endedAt']),
  );

  final String championName;
  final String? championImageUrl;
  final bool win;
  final int kills;
  final int deaths;
  final int assists;
  final int durationSeconds;
  final DateTime? endedAt;
}

class PlayerNextMatch {
  const PlayerNextMatch({
    required this.matchId,
    required this.leagueName,
    required this.stage,
    required this.bestOf,
    required this.team,
    required this.opponent,
    this.scheduledAt,
    this.stakeLabel,
  });

  factory PlayerNextMatch.fromJson(Map<String, dynamic> j) => PlayerNextMatch(
    matchId: j['matchId']?.toString() ?? '',
    leagueName: j['leagueName'] as String? ?? '',
    stage: j['stage'] as String? ?? '',
    scheduledAt: parseServerTime(j['scheduledAt']),
    bestOf: _int(j['bestOf']),
    team: PlayerMatchTeam.fromJson(
      j['team'] as Map<String, dynamic>? ?? const {},
    ),
    opponent: PlayerMatchTeam.fromJson(
      j['opponent'] as Map<String, dynamic>? ?? const {},
    ),
    stakeLabel: j['stakeLabel'] as String?,
  );

  final String matchId;
  final String leagueName;

  /// 표시용 문자열 그대로("스위스 4라운드").
  final String stage;
  final DateTime? scheduledAt;
  final int bestOf;
  final PlayerMatchTeam team;
  final PlayerMatchTeam opponent;

  /// "이기면 8강 진출". null 가능.
  final String? stakeLabel;

  bool get isWorlds => leagueName.toUpperCase() == 'WORLDS';
}

class PlayerMatchTeam {
  const PlayerMatchTeam({
    required this.teamCode,
    required this.teamName,
    required this.wins,
    required this.losses,
    this.teamImageUrl,
  });

  factory PlayerMatchTeam.fromJson(Map<String, dynamic> j) => PlayerMatchTeam(
    teamCode: j['teamCode'] as String? ?? '',
    teamName: j['teamName'] as String? ?? '',
    teamImageUrl: j['teamImageUrl'] as String?,
    wins: _int(j['wins']),
    losses: _int(j['losses']),
  );

  final String teamCode;
  final String teamName;
  final String? teamImageUrl;
  final int wins;
  final int losses;
}

/// 평균 평점과 참여 수. 평점이 없으면 이 객체 자체가 null 이다.
class PlayerRatingSummary {
  const PlayerRatingSummary({required this.average, required this.count});

  static PlayerRatingSummary? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    return PlayerRatingSummary(
      average: _double(raw['average']) ?? 0,
      count: _int(raw['count']),
    );
  }

  final double average;
  final int count;
}

class PlayerStats {
  const PlayerStats({
    required this.subscriberCount,
    required this.cheers7d,
    this.worldsRating,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> j) => PlayerStats(
    subscriberCount: _int(j['subscriberCount']),
    cheers7d: _int(j['cheers7d']),
    worldsRating: PlayerRatingSummary.fromJson(j['worldsRating']),
  );

  final int subscriberCount;
  final int cheers7d;
  final PlayerRatingSummary? worldsRating;
}

/// 월즈 탭 (`GET /api/mobile/players/{playerId}/worlds`).
class PlayerWorlds {
  const PlayerWorlds({
    required this.games,
    required this.wins,
    required this.losses,
    required this.stats,
    required this.matches,
    required this.champions,
    this.rating,
  });

  factory PlayerWorlds.fromJson(Map<String, dynamic> j) {
    final record = j['record'] as Map<String, dynamic>? ?? const {};
    final rating = j['rating'] as Map<String, dynamic>?;
    return PlayerWorlds(
      games: _int(record['games']),
      wins: _int(record['wins']),
      losses: _int(record['losses']),
      stats: [for (final e in _list(j['stats'])) PlayerWorldsStat.fromJson(e)],
      matches: [
        for (final e in _list(j['games'])) PlayerWorldsGame.fromJson(e),
      ],
      champions: [
        for (final e in _list(j['champions'])) PlayerChampionRecord.fromJson(e),
      ],
      rating: rating == null ? null : PlayerWorldsRating.fromJson(rating),
    );
  }

  /// 세트 기준 전적.
  final int games;
  final int wins;
  final int losses;

  /// 순서 그대로 2열×3행 그리드. 기록 없으면 빈 목록.
  final List<PlayerWorldsStat> stats;

  /// 경기별 기록(응답 `games`), 최신순.
  final List<PlayerWorldsGame> matches;

  /// 솔랭(최근 20판)·월즈 합집합. 정렬은 화면이 한다.
  final List<PlayerChampionRecord> champions;
  final PlayerWorldsRating? rating;
}

class PlayerWorldsStat {
  const PlayerWorldsStat({
    required this.key,
    required this.value,
    this.positionAvg,
    this.positionRank,
    this.positionCount,
  });

  factory PlayerWorldsStat.fromJson(Map<String, dynamic> j) => PlayerWorldsStat(
    key: j['key'] as String? ?? '',
    value: _double(j['value']) ?? 0,
    positionAvg: _double(j['positionAvg']),
    positionRank: (j['positionRank'] as num?)?.toInt(),
    positionCount: (j['positionCount'] as num?)?.toInt(),
  );

  /// KDA · KP · DPM · CSPM · GD15 · VSPM.
  final String key;
  final double value;
  final double? positionAvg;
  final int? positionRank;
  final int? positionCount;
}

class PlayerWorldsGame {
  const PlayerWorldsGame({
    required this.gameId,
    required this.win,
    required this.stage,
    required this.opponentTeamCode,
    required this.opponentTeamName,
    required this.championName,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.cs,
    required this.damage,
    this.playedAt,
    this.opponentTeamImageUrl,
    this.championImageUrl,
    this.rating,
  });

  factory PlayerWorldsGame.fromJson(Map<String, dynamic> j) => PlayerWorldsGame(
    gameId: j['gameId']?.toString() ?? '',
    playedAt: parseServerTime(j['playedAt']),
    win: j['win'] as bool? ?? false,
    stage: j['stage'] as String? ?? '',
    opponentTeamCode: j['opponentTeamCode'] as String? ?? '',
    opponentTeamImageUrl: j['opponentTeamImageUrl'] as String?,
    opponentTeamName: j['opponentTeamName'] as String? ?? '',
    championName: j['championName'] as String? ?? '',
    championImageUrl: j['championImageUrl'] as String?,
    kills: _int(j['kills']),
    deaths: _int(j['deaths']),
    assists: _int(j['assists']),
    cs: _int(j['cs']),
    damage: _int(j['damage']),
    rating: PlayerRatingSummary.fromJson(j['rating']),
  );

  final String gameId;
  final DateTime? playedAt;
  final bool win;

  /// 라운드 없는 블록명("스위스", "8강") 그대로 표시한다.
  final String stage;

  /// 해외 팀은 상류 CSV 에 코드·로고가 없을 수 있다(빈 값) — 그때는 [opponentTeamName].
  final String opponentTeamCode;
  final String opponentTeamName;
  final String? opponentTeamImageUrl;

  /// 표시용 상대 팀 — 코드가 없으면 이름.
  String get opponentLabel =>
      opponentTeamCode.isNotEmpty ? opponentTeamCode : opponentTeamName;
  final String championName;
  final String? championImageUrl;
  final int kills;
  final int deaths;
  final int assists;
  final int cs;
  final int damage;
  final PlayerRatingSummary? rating;
}

class PlayerChampionRecord {
  const PlayerChampionRecord({
    required this.championName,
    required this.soloWins,
    required this.soloLosses,
    required this.worldsWins,
    required this.worldsLosses,
    this.championImageUrl,
  });

  factory PlayerChampionRecord.fromJson(Map<String, dynamic> j) =>
      PlayerChampionRecord(
        championName: j['championName'] as String? ?? '',
        championImageUrl: j['championImageUrl'] as String?,
        soloWins: _int(j['soloWins']),
        soloLosses: _int(j['soloLosses']),
        worldsWins: _int(j['worldsWins']),
        worldsLosses: _int(j['worldsLosses']),
      );

  final String championName;
  final String? championImageUrl;
  final int soloWins;
  final int soloLosses;
  final int worldsWins;
  final int worldsLosses;

  int get soloGames => soloWins + soloLosses;
  int get worldsGames => worldsWins + worldsLosses;
}

class PlayerWorldsRating {
  const PlayerWorldsRating({
    required this.average,
    required this.count,
    required this.distribution,
    required this.reviews,
    required this.reviewCount,
  });

  factory PlayerWorldsRating.fromJson(Map<String, dynamic> j) =>
      PlayerWorldsRating(
        average: _double(j['average']) ?? 0,
        count: _int(j['count']),
        distribution: {
          for (final e in _list(j['distribution']))
            _int(e['rating']): _double(e['percentage']) ?? 0,
        },
        reviews: [
          for (final e in _list(j['reviews'])) PlayerReview.fromJson(e),
        ],
        reviewCount: _int(j['reviewCount']),
      );

  final double average;
  final int count;

  /// 점수(5..1) → 비율(%).
  final Map<int, double> distribution;

  /// 최신 코멘트 최대 3개.
  final List<PlayerReview> reviews;
  final int reviewCount;
}

class PlayerReview {
  const PlayerReview({
    required this.rating,
    required this.comment,
    required this.opponentTeamCode,
    required this.stage,
    this.ratingId,
    this.gameId,
    this.participantId,
    this.teamSide,
  });

  factory PlayerReview.fromJson(Map<String, dynamic> e) => PlayerReview(
    ratingId: (e['ratingId'] as num?)?.toInt(),
    gameId: e['gameId']?.toString(),
    participantId: (e['participantId'] as num?)?.toInt(),
    teamSide: e['teamSide'] as String?,
    rating: _int(e['rating']),
    comment: e['comment'] as String? ?? '',
    opponentTeamCode: e['opponentTeamCode'] as String? ?? '',
    stage: e['stage'] as String? ?? '',
  );

  final int rating;
  final String comment;
  final String opponentTeamCode;
  final String stage;

  /// 그 판 평점 상세(PlayerRatingScreen)로 가는 키. 옛 서버면 null — 탭해도 반응 없다.
  final int? ratingId;

  /// 라이브 게임 id·참가자 id.
  final String? gameId;
  final int? participantId;

  /// "Blue" / "Red".
  final String? teamSide;

  bool get canOpen =>
      gameId != null && gameId!.isNotEmpty && participantId != null;
}

/// 한줄평 한 페이지 (`GET /api/mobile/players/{id}/worlds/reviews`).
class PlayerReviewPage {
  const PlayerReviewPage({
    required this.reviews,
    required this.totalCount,
    required this.hasNext,
  });

  factory PlayerReviewPage.fromJson(Map<String, dynamic> j) => PlayerReviewPage(
    reviews: [for (final e in _list(j['reviews'])) PlayerReview.fromJson(e)],
    totalCount: _int(j['totalCount']),
    hasNext: j['hasNext'] as bool? ?? false,
  );

  final List<PlayerReview> reviews;
  final int totalCount;
  final bool hasNext;
}

/// 솔랭 탭 (`GET /api/mobile/players/{playerId}/solo-rank`).
class PlayerSoloRank {
  const PlayerSoloRank({
    required this.accounts,
    required this.recent,
    required this.champions,
    required this.games,
    this.metPlayers = const [],
  });

  factory PlayerSoloRank.fromJson(Map<String, dynamic> j) => PlayerSoloRank(
    accounts: [
      for (final e in _list(j['accounts']))
        PlayerSoloAccount(
          region: e['region'] as String? ?? '',
          riotId: e['riotId'] as String? ?? '',
          tier: e['tier'] as String?,
          live: e['live'] as bool? ?? false,
        ),
    ],
    recent: PlayerSoloRecent.fromJson(
      j['recent'] as Map<String, dynamic>? ?? const {},
    ),
    champions: [
      for (final e in _list(j['champions']))
        PlayerSoloChampion(
          championName: e['championName'] as String? ?? '',
          championImageUrl: e['championImageUrl'] as String?,
          games: _int(e['games']),
          wins: _int(e['wins']),
          kda: _double(e['kda']) ?? 0,
        ),
    ],
    games: [
      for (final e in _list(j['games']))
        PlayerSoloGame(
          gameId: e['gameId']?.toString() ?? '',
          championName: e['championName'] as String? ?? '',
          championImageUrl: e['championImageUrl'] as String?,
          win: e['win'] as bool? ?? false,
          kills: _int(e['kills']),
          deaths: _int(e['deaths']),
          assists: _int(e['assists']),
          durationSeconds: _int(e['durationSeconds']),
          endedAt: parseServerTime(e['endedAt']),
          cheerTotal: _int(e['cheerTotal']),
        ),
    ],
    metPlayers: [for (final e in _list(j['metPlayers'])) PlayerMet.fromJson(e)],
  );

  final List<PlayerSoloAccount> accounts;
  final PlayerSoloRecent recent;
  final List<PlayerSoloChampion> champions;

  /// 최근 20판, 최신순.
  final List<PlayerSoloGame> games;

  /// 최근 7일 솔랭에서 만난 프로 선수(함께한 판 많은 순, 최대 10명). 옛 서버면 빈 목록.
  final List<PlayerMet> metPlayers;
}

/// 솔랭에서 만난 선수 한 명. 승패는 **이 페이지 선수** 기준이다.
class PlayerMet {
  const PlayerMet({
    required this.playerId,
    required this.playerName,
    required this.sameTeamGames,
    required this.sameTeamWins,
    required this.opponentGames,
    required this.opponentWins,
    required this.opponentLosses,
    this.playerImageUrl,
    this.teamCode,
    this.teamImageUrl,
    this.lastMetAt,
  });

  factory PlayerMet.fromJson(Map<String, dynamic> j) => PlayerMet(
    playerId: _int(j['playerId']),
    playerName: j['playerName'] as String? ?? '',
    playerImageUrl: j['playerImageUrl'] as String?,
    teamCode: j['teamCode'] as String?,
    teamImageUrl: j['teamImageUrl'] as String?,
    sameTeamGames: _int(j['sameTeamGames']),
    sameTeamWins: _int(j['sameTeamWins']),
    opponentGames: _int(j['opponentGames']),
    opponentWins: _int(j['opponentWins']),
    opponentLosses: _int(j['opponentLosses']),
    lastMetAt: parseServerTime(j['lastMetAt']),
  );

  final int playerId;
  final String playerName;
  final String? playerImageUrl;

  /// null 가능(소속 없는 선수 등).
  final String? teamCode;
  final String? teamImageUrl;
  final int sameTeamGames;
  final int sameTeamWins;
  final int opponentGames;
  final int opponentWins;
  final int opponentLosses;
  final DateTime? lastMetAt;
}

class PlayerSoloAccount {
  const PlayerSoloAccount({
    required this.region,
    required this.riotId,
    required this.live,
    this.tier,
  });

  final String region;
  final String riotId;

  /// 크롤링 값이라 null 일 수 있다 — 그때는 티어 텍스트를 생략한다.
  final String? tier;
  final bool live;

  /// 크롤러(TrackingThePros)가 주는 티어 표기 → (문장 키, 약어). 약어(Ch, GM)로도 온다.
  static const _crestTiers = {
    'iron': ('iron', 'I'),
    'bronze': ('bronze', 'B'),
    'silver': ('silver', 'S'),
    'gold': ('gold', 'G'),
    'platinum': ('platinum', 'P'),
    'emerald': ('emerald', 'E'),
    'diamond': ('diamond', 'D'),
    'master': ('master', 'M'),
    'grandmaster': ('grandmaster', 'GM'),
    'gm': ('grandmaster', 'GM'),
    'challenger': ('challenger', 'C'),
    'ch': ('challenger', 'C'),
  };

  /// [tier] 첫 단어가 아는 티어면 (문장 키, 약어로 바꾼 표기) 로 나눈다.
  /// 'Master 1,213LP' → ('master', 'M 1,213LP'). 모르는 티어면 null — 원문을 그대로 쓴다.
  (String, String)? get tierCrest {
    final parts = (tier ?? '').trim().split(RegExp(r'\s+'));
    final hit = _crestTiers[parts.first.toLowerCase()];
    if (hit == null) return null;
    return (hit.$1, [hit.$2, ...parts.skip(1)].join(' '));
  }
}

class PlayerSoloRecent {
  const PlayerSoloRecent({
    required this.games,
    required this.wins,
    required this.losses,
    required this.avgKills,
    required this.avgDeaths,
    required this.avgAssists,
    required this.kda,
    required this.gamesPerDay,
    required this.avgDurationSeconds,
    required this.results,
  });

  factory PlayerSoloRecent.fromJson(Map<String, dynamic> j) => PlayerSoloRecent(
    games: _int(j['games']),
    wins: _int(j['wins']),
    losses: _int(j['losses']),
    avgKills: _double(j['avgKills']) ?? 0,
    avgDeaths: _double(j['avgDeaths']) ?? 0,
    avgAssists: _double(j['avgAssists']) ?? 0,
    kda: _double(j['kda']) ?? 0,
    gamesPerDay: _double(j['gamesPerDay']) ?? 0,
    avgDurationSeconds: _int(j['avgDurationSeconds']),
    results: [
      for (final r in j['results'] as List<dynamic>? ?? const []) r == true,
    ],
  );

  final int games;
  final int wins;
  final int losses;
  final double avgKills;
  final double avgDeaths;
  final double avgAssists;
  final double kda;
  final double gamesPerDay;
  final int avgDurationSeconds;

  /// 오래된→최신 순 승패.
  final List<bool> results;
}

class PlayerSoloChampion {
  const PlayerSoloChampion({
    required this.championName,
    required this.games,
    required this.wins,
    required this.kda,
    this.championImageUrl,
  });

  final String championName;
  final String? championImageUrl;
  final int games;
  final int wins;
  final double kda;
}

class PlayerSoloGame {
  const PlayerSoloGame({
    required this.gameId,
    required this.championName,
    required this.win,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.durationSeconds,
    required this.cheerTotal,
    this.championImageUrl,
    this.endedAt,
  });

  final String gameId;
  final String championName;
  final String? championImageUrl;
  final bool win;
  final int kills;
  final int deaths;
  final int assists;
  final int durationSeconds;
  final DateTime? endedAt;
  final int cheerTotal;
}
