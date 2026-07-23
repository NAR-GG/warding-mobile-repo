import '../l10n/app_strings.dart';
import '../util/champion_image.dart';

/// 라이브 이벤트 종류.
enum LiveEventType { kill, dragon, baron, tower, inhibitor, unknown }

/// `GET /api/mobile/live/games/{gameId}/events` 응답 전체.
///
/// 최상위에 양 팀명·팀 로고 URL을 담고, `events`에 이벤트 목록을 담는다.
/// 오브젝트 이벤트는 [teamSide]로 어느 팀 로고를 쓸지 정한다.
class MatchLiveEvents {
  const MatchLiveEvents({
    this.gameId,
    this.blueTeamName,
    this.blueTeamImageUrl,
    this.redTeamName,
    this.redTeamImageUrl,
    this.events = const [],
  });

  final String? gameId;
  final String? blueTeamName;
  final String? blueTeamImageUrl;
  final String? redTeamName;
  final String? redTeamImageUrl;
  final List<MatchLiveEvent> events;

  /// teamSide('Blue'/'Red')로 해당 팀의 로고 URL을 고른다. 없으면 null.
  String? logoUrlForSide(String? teamSide) {
    final s = (teamSide ?? '').toLowerCase();
    if (s == 'blue') return blueTeamImageUrl;
    if (s == 'red') return redTeamImageUrl;
    return null;
  }

  factory MatchLiveEvents.fromJson(Map<String, dynamic> json) {
    final list = json['events'] as List<dynamic>? ?? const [];
    return MatchLiveEvents(
      gameId: json['gameId'] as String?,
      blueTeamName: json['blueTeamName'] as String?,
      blueTeamImageUrl: json['blueTeamImageUrl'] as String?,
      redTeamName: json['redTeamName'] as String?,
      redTeamImageUrl: json['redTeamImageUrl'] as String?,
      events: list
          .map((e) => MatchLiveEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 경기 상세 — 라이브 이벤트 탭 한 건.
///
/// `GET /api/mobile/live/games/{gameId}/events` 의 `events` 항목 하나에 대응한다.
/// - KILL: [killer]/[victim] 보유 (챔피언 vs 챔피언).
/// - DRAGON/BARON/TOWER/INHIBITOR: [teamName]/[teamSide]/[subType]/[count] 보유.
class MatchLiveEvent {
  const MatchLiveEvent({
    required this.type,
    required this.gameTime,
    required this.gameTimeSeconds,
    this.killer,
    this.victim,
    this.teamKillCount,
    this.subType,
    this.teamSide,
    this.teamName,
    this.count,
  });

  final LiveEventType type;

  /// 게임 내 시각 표시 문자열 (예: '17:34').
  final String gameTime;
  final int gameTimeSeconds;

  // ── KILL ─────────────────────────────────────
  final LiveEventActor? killer;
  final LiveEventActor? victim;
  final int? teamKillCount;

  // ── 오브젝트 (DRAGON/BARON/TOWER/INHIBITOR) ──
  /// 드래곤 속성 등 세부 타입 (예: '바람').
  final String? subType;

  /// 'Blue' | 'Red'.
  final String? teamSide;
  final String? teamName;
  final int? count;

  bool get isKill => type == LiveEventType.kill;

  factory MatchLiveEvent.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? '').toUpperCase();
    final type = switch (rawType) {
      'KILL' => LiveEventType.kill,
      'DRAGON' => LiveEventType.dragon,
      'BARON' => LiveEventType.baron,
      'TOWER' => LiveEventType.tower,
      'INHIBITOR' => LiveEventType.inhibitor,
      _ => LiveEventType.unknown,
    };
    final killerJson = json['killer'] as Map<String, dynamic>?;
    final victimJson = json['victim'] as Map<String, dynamic>?;
    return MatchLiveEvent(
      type: type,
      gameTime: json['gameTime'] as String? ?? '',
      gameTimeSeconds: json['gameTimeSeconds'] as int? ?? 0,
      killer: killerJson == null ? null : LiveEventActor.fromJson(killerJson),
      victim: victimJson == null ? null : LiveEventActor.fromJson(victimJson),
      teamKillCount: json['teamKillCount'] as int?,
      subType: json['subType'] as String?,
      teamSide: json['teamSide'] as String?,
      teamName: json['teamName'] as String?,
      count: json['count'] as int?,
    );
  }

  /// 오브젝트 이벤트의 표시 라벨 (예: '바람드래곤', '바론', '타워', '억제기').
  String objectiveLabel() {
    switch (type) {
      case LiveEventType.dragon:
        final sub = subType?.trim();
        if (sub != null && sub.isNotEmpty) {
          return appStrings?.objectSubDragon(sub) ?? '$sub Dragon';
        }
        return appStrings?.objectDragon ?? 'Dragon';
      case LiveEventType.baron:
        return appStrings?.objectBaron ?? 'Baron';
      case LiveEventType.tower:
        return appStrings?.objectTower ?? 'Tower';
      case LiveEventType.inhibitor:
        return appStrings?.objectInhibitor ?? 'Inhibitor';
      case LiveEventType.kill:
      case LiveEventType.unknown:
        return subType ?? '';
    }
  }

  /// 오브젝트 이벤트의 로컬 아이콘 에셋 경로. 매칭 에셋이 없으면 null.
  String? objectiveAsset() {
    switch (type) {
      case LiveEventType.dragon:
        return _dragonAsset(subType);
      case LiveEventType.baron:
        return 'assets/images/baron.png';
      case LiveEventType.tower:
        return 'assets/images/turret.png';
      case LiveEventType.inhibitor:
        return 'assets/images/inhibitor.png';
      case LiveEventType.kill:
      case LiveEventType.unknown:
        return null;
    }
  }

  /// 드래곤 속성(한국어) → 로컬 드래곤 에셋.
  static String? _dragonAsset(String? subType) {
    final s = subType?.trim() ?? '';
    if (s.contains('바람') || s.toLowerCase().contains('cloud')) {
      return 'assets/images/cloud-dragon.png';
    }
    if (s.contains('바다') || s.toLowerCase().contains('ocean')) {
      return 'assets/images/ocean-dragon.png';
    }
    if (s.contains('대지') || s.contains('산') ||
        s.toLowerCase().contains('mountain')) {
      return 'assets/images/mountain-dragon.png';
    }
    if (s.contains('화염') || s.contains('불') ||
        s.toLowerCase().contains('infernal')) {
      return 'assets/images/infernal-dragon.png';
    }
    if (s.contains('마법공학') || s.toLowerCase().contains('hextech')) {
      return 'assets/images/hextech-dragon.png';
    }
    if (s.contains('화학공학') || s.toLowerCase().contains('chemtech')) {
      return 'assets/images/chemtech-dragon.png';
    }
    if (s.contains('장로') || s.toLowerCase().contains('elder')) {
      return 'assets/images/elder-dragon.png';
    }
    // 속성 미상이면 기본 드래곤 아이콘.
    return 'assets/images/cloud-dragon.png';
  }
}

/// 킬 이벤트의 한 쪽(킬러/희생자).
class LiveEventActor {
  const LiveEventActor({
    required this.playerName,
    required this.championName,
    required this.teamSide,
    this.championImageUrl,
  });

  final String playerName;
  final String championName;

  /// 'Blue' | 'Red'.
  final String teamSide;
  final String? championImageUrl;

  /// 표시용 챔피언 이미지 URL (백엔드 값 없으면 Data Dragon 폴백).
  String? get imageUrl =>
      ChampionImage.resolve(championImageUrl, championName);

  factory LiveEventActor.fromJson(Map<String, dynamic> json) {
    return LiveEventActor(
      playerName: json['playerName'] as String? ?? '',
      championName: json['championName'] as String? ?? '',
      teamSide: json['teamSide'] as String? ?? '',
      championImageUrl: json['championImageUrl'] as String?,
    );
  }
}
