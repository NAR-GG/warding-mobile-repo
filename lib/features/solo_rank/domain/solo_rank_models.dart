// 솔로 랭크 선수 카드 모델. 홈·선수 상세·내 선수 세 화면이 함께 쓴다.
//
// 원래 `features/home/domain/home_models.dart` 에 있었는데, 홈 전용이 아니라
// `player`·`my_players` 도 쓰는 것이 드러나 솔랭 기능으로 올렸다.
/// 지금 솔로 랭크 중인 선수 카드 한 장.
class HomeLiveSoloPlayer {
  const HomeLiveSoloPlayer({
    required this.name,
    required this.teamCode,
    required this.champion,
    required this.elapsedSeconds,
    this.playerImageUrl,
    this.championImageUrl,
    this.startedAt,
    this.playerId,
    this.cheerTotal = 0,
    this.cheerMine = 0,
    this.platform,
    this.teamImageUrl,
  });

  final String name;
  final String teamCode;
  final String champion;

  /// 응답이 준 팀 로고. 로고 사전(LCK 팀만)에 없는 해외 팀일 때만 쓴다. 옛 서버면 null.
  final String? teamImageUrl;

  /// 이 판을 하는 계정의 플랫폼(KR / NA1 …). 옛 서버라 없으면 null.
  /// KR 이 아니면 해외 계정(월즈 부트캠프 계정 등)이라 화면에 지역을 붙인다.
  final String? platform;

  /// 해외 계정으로 하는 판이면 "NA" 같은 짧은 지역 표기, KR·모름이면 null.
  String? get overseasRegion {
    final p = platform;
    if (p == null || p.isEmpty || p.toUpperCase() == 'KR') return null;
    return p.toUpperCase().replaceAll(RegExp(r'\d+$'), '');
  }

  /// 응원 전송에 쓰는 선수 id. 솔랭 응답이 주면 쓰고, 없으면 홈 뷰모델이 구독
  /// 목록에서 이름으로 찾아 채운다.
  final int? playerId;

  /// 이 판 전체 응원 수(서버 값). 옛 서버라 필드가 없으면 0.
  final int cheerTotal;

  /// 내가 이 판에 보낸 응원 수(서버 값). 옛 서버라 필드가 없으면 0.
  final int cheerMine;

  /// 백엔드가 주는 챔피언 이미지 URL. 있으면 [champion] 이름으로 Data Dragon
  /// 주소를 짜맞추는 것보다 이걸 먼저 쓴다 — 이름→키 변환을 거치지 않아
  /// 신챔·개명에도 깨지지 않는다. 없으면 이름으로 폴백한다.
  final String? championImageUrl;

  /// 조회 시점 기준 경과 시간(초). [startedAt] 이 있으면 화면은 그 시각으로
  /// 초 단위 카운트업하고, 이 값은 게임 길이 안내 등 조회 시점 스냅샷에만 쓴다.
  final int elapsedSeconds;

  /// 선수 사진 URL(상대경로면 호스트 부착). 없으면 빈 자리 유지.
  final String? playerImageUrl;

  /// 게임 시작 시각. 있으면 기기 시계로 [elapsedSeconds] 를 매초 다시 계산해
  /// 카운트업한다(spec 미룬 것 — "기기 시계 카운트업"). 없으면 [elapsedSeconds]
  /// 를 고정값으로 보여준다.
  final DateTime? startedAt;
}

/// 오늘 솔로 랭크를 끝낸 선수 한 명(최신 1건).
class HomeFinishedSoloPlayer {
  const HomeFinishedSoloPlayer({
    required this.name,
    required this.teamCode,
    required this.won,
    required this.minutesAgo,
    this.durationMinutes,
    this.playerImageUrl,
    this.cheerTotal = 0,
    this.playerId,
  });

  final String name;
  final String teamCode;
  final bool won;

  /// 선수 페이지 진입용 id. 옛 서버·목업이면 null 이고 칩을 눌러도 반응 없다.
  final int? playerId;

  /// 그 판의 응원 합계(서버 값). 0 이면 칩에 그리지 않는다.
  final int cheerTotal;

  /// 선수 사진 URL(상대경로면 호스트 부착). 없으면 이름 이니셜로 대신한다.
  final String? playerImageUrl;

  /// 끝난 지 몇 분 됐는지 — "12분 전 종료".
  final int minutesAgo;

  /// 경기 길이(분) — "32분". 소스가 주지 않으면 null 이고 그리지 않는다.
  final int? durationMinutes;
}

/// 순위표 리그 칩 하나. [live]가 false면 아직 데이터가 없는 리그(탭 불가).
