import '../l10n/app_strings.dart';

/// 특정 날짜의 경기 한 건.
///
/// `특정 날짜 경기 목록` API 응답의 `matches` 항목 하나에 대응한다.
class ScheduleMatch {
  const ScheduleMatch({
    required this.matchId,
    required this.scheduledTime,
    required this.leagueInfo,
    required this.matchTitle,
    required this.matchStatus,
    required this.isSynced,
    required this.teamA,
    required this.teamB,
    this.date,
    this.liveStreamUrl,
    this.streamLinks = const [],
    this.sets = const [],
  });

  final String matchId;

  /// 경기 날짜 (yyyy-MM-dd). 커서 페이지 응답에 포함되며, 날짜별 그룹핑에 쓴다.
  /// 날짜별 조회 응답에는 없을 수 있어 null 을 허용한다.
  final DateTime? date;

  /// 경기 예정 시각 (서버가 문자열로 내려준다).
  final String scheduledTime;

  /// 리그 정보 (예: 'LCK').
  final String leagueInfo;

  final String matchTitle;

  /// 경기 상태 (예정/진행/종료 등).
  final String matchStatus;

  final bool isSynced;

  /// 홈 팀.
  final MatchTeam teamA;

  /// 원정 팀.
  final MatchTeam teamB;

  /// 라이브 중계 URL. 없을 수 있다. (하위호환 — streamLinks 첫 번째와 동일)
  final String? liveStreamUrl;

  /// 라이브 중계 채널 목록. 복수면 유저가 플랫폼을 고른다(치지직/SOOP 등).
  final List<StreamLink> streamLinks;

  /// 실제로 열 수 있는 중계 링크 목록. streamLinks 가 비어 있으면
  /// (구버전 서버 응답) liveStreamUrl 하나로 폴백한다.
  List<StreamLink> get effectiveStreamLinks {
    if (streamLinks.isNotEmpty) return streamLinks;
    final url = liveStreamUrl;
    if (url == null || url.isEmpty) return const [];
    return [StreamLink(provider: 'default', label: appStrings?.watchBroadcastFallback ?? 'Watch', description: '', url: url)];
  }

  /// 세트별 정보 (VOD 등).
  final List<MatchSet> sets;

  factory ScheduleMatch.fromJson(Map<String, dynamic> json) {
    // 모바일 API(`/api/mobile/schedules`)는 blueTeam/redTeam·leagueName 키를,
    // 구 API는 teamA/teamB·leagueInfo 키를 쓴다. 둘 다 받아 준다.
    final blue = (json['teamA'] ?? json['blueTeam']) as Map<String, dynamic>;
    final red = (json['teamB'] ?? json['redTeam']) as Map<String, dynamic>;
    return ScheduleMatch(
      matchId: json['matchId'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? '',
      leagueInfo:
          (json['leagueInfo'] ?? json['leagueName']) as String? ?? '',
      matchTitle: json['matchTitle'] as String? ?? '',
      matchStatus: json['matchStatus'] as String? ?? '',
      isSynced: json['isSynced'] as bool? ?? false,
      date: _parseDate(json['date'] as String?),
      teamA: MatchTeam.fromJson(blue),
      teamB: MatchTeam.fromJson(red),
      liveStreamUrl: json['liveStreamUrl'] as String?,
      streamLinks: (json['streamLinks'] as List<dynamic>? ?? const [])
          .map((e) => StreamLink.fromJson(e as Map<String, dynamic>))
          .toList(),
      sets: (json['sets'] as List<dynamic>? ?? const [])
          .map((e) => MatchSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 'yyyy-MM-dd' 문자열을 자정 기준 [DateTime] 으로 파싱한다. 실패·null 이면 null.
  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}

/// 라이브 중계 채널 하나 (플랫폼 + 링크).
class StreamLink {
  const StreamLink({
    required this.provider,
    required this.label,
    required this.description,
    required this.url,
  });

  /// 플랫폼 식별자 (chzzk/soop/twitch 등).
  final String provider;

  /// 표시 이름 (치지직/SOOP 등).
  final String label;

  /// 부가 설명 (예: 'LCK 공식 채널 · 한국어').
  final String description;

  final String url;

  factory StreamLink.fromJson(Map<String, dynamic> json) {
    return StreamLink(
      provider: json['provider'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

/// 경기에 출전하는 팀 한 쪽.
class MatchTeam {
  const MatchTeam({
    required this.teamName,
    required this.teamCode,
    required this.teamImageUrl,
    required this.score,
  });

  final String teamName;

  /// 짧은 팀 코드 (예: 'T1', 'GEN'). 캘린더 칩에 표시한다.
  final String teamCode;

  final String teamImageUrl;

  /// 현재 스코어.
  final int score;

  factory MatchTeam.fromJson(Map<String, dynamic> json) {
    return MatchTeam(
      teamName: json['teamName'] as String? ?? '',
      teamCode: json['teamCode'] as String? ?? '',
      teamImageUrl: json['teamImageUrl'] as String? ?? '',
      score: json['score'] as int? ?? 0,
    );
  }
}

/// 경기 세트 한 개.
class MatchSet {
  const MatchSet({required this.setNumber, this.vodUrl});

  final int setNumber;

  /// 세트 VOD URL. 없을 수 있다.
  final String? vodUrl;

  factory MatchSet.fromJson(Map<String, dynamic> json) {
    return MatchSet(
      setNumber: json['setNumber'] as int? ?? 0,
      vodUrl: json['vodUrl'] as String?,
    );
  }
}
