import '../../model/home_models.dart';
import '../../repository/home/home_sources.dart';

/// 솔랭 상태 분류 규칙 — 홈 솔랭 카드와 내 선수 화면이 함께 쓴다.
///
/// 두 화면이 같은 선수를 다르게 분류하면(홈에서는 솔랭 중인데 내 선수에서는
/// 소식 없음 등) 숫자가 어긋나므로, 규칙은 이 한 곳에만 둔다.
///
/// - 선수 매칭 키는 이름이다(솔랭 `name` == 구독 `playerName`).
/// - [subscribed] 가 주어지면 그 이름의 선수만 남긴다.
/// - 진행 중인 선수는 끝난 경기에서 뺀다 — 위 큰 카드에 이미 있어서, 남기면
///   같은 선수가 두 번 나오고 숨김 수도 두 번 빠진다(spec 결정).
/// - 끝난 경기는 선수당 가장 최근(minutesAgo 최소) 1건만 남긴다.
///
/// 끝난 경기 최대 8명 같은 표시 상한은 홈 카드만의 규칙이라 여기 두지 않는다.
class SoloRankClassification {
  const SoloRankClassification._(this.liveByName, this.finishedByName);

  /// 분류한다. [snap] 이 null 이면(아직 못 받음) 둘 다 비어 있다.
  factory SoloRankClassification.of(
    SoloRankSnapshot? snap, {
    Set<String>? subscribed,
  }) {
    bool keep(String name) => subscribed == null || subscribed.contains(name);

    final live = <String, HomeLiveSoloPlayer>{
      for (final p in snap?.live ?? const <HomeLiveSoloPlayer>[])
        if (keep(soloKey(p.name))) soloKey(p.name): p,
    };
    final finished = <String, HomeFinishedSoloPlayer>{};
    for (final p in snap?.finished ?? const <HomeFinishedSoloPlayer>[]) {
      final key = soloKey(p.name);
      if (!keep(key) || live.containsKey(key)) continue;
      final prev = finished[key];
      if (prev == null || p.minutesAgo < prev.minutesAgo) finished[key] = p;
    }
    return SoloRankClassification._(live, finished);
  }

  /// 선수 매칭 키. 지금은 이름 그대로다(솔랭 DTO 에 playerId 가 생기면 교체).
  static String soloKey(String name) => name;

  /// 진행 중인 선수 — 키별 1건.
  final Map<String, HomeLiveSoloPlayer> liveByName;

  /// 오늘 끝난 경기 — 진행 중 선수를 뺀, 키별 가장 최근 1건.
  final Map<String, HomeFinishedSoloPlayer> finishedByName;

  /// 진행 중: 가장 최근에 시작한(경과 시간 짧은) 선수가 먼저.
  static int compareLive(HomeLiveSoloPlayer a, HomeLiveSoloPlayer b) =>
      a.elapsedSeconds.compareTo(b.elapsedSeconds);

  /// 끝난 경기: 가장 최근에 끝난 선수가 먼저.
  static int compareFinished(
    HomeFinishedSoloPlayer a,
    HomeFinishedSoloPlayer b,
  ) => a.minutesAgo.compareTo(b.minutesAgo);
}
