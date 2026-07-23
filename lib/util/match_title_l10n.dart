import '../l10n/app_localizations.dart';

/// 서버의 matchTitle 에 포함된 한국어 경기 종류를 로케일에 맞게 변환한다.
///
/// 예: "LPL 1주 차 | TES vs BLG" → "LPL Week 1 | TES vs BLG" (영어)
String localizeMatchTitle(String title, AppLocalizations l) {
  var result = title;

  // N주 차 → Week N
  result = result.replaceAllMapped(
    RegExp(r'(\d+)주\s*차'),
    (m) => l.weekRound(int.parse(m.group(1)!)),
  );

  // N강 → Top N (4강, 8강 등)
  result = result.replaceAllMapped(
    RegExp(r'(\d+)강'),
    (m) => l.nthRound(int.parse(m.group(1)!)),
  );

  // 긴 문구 먼저 매칭해야 짧은 것에 먹히지 않는다.
  final stageMap = {
    '플레이-인 토너먼트 스테이지': l.stagePlayInTournament,
    '토너먼트 스테이지': l.stageTournament,
    '플레이-인': l.stagePlayIn,
    '플레이오프': l.stagePlayoff,
    '그룹': l.stageGroup,
    '스위스': l.stageSwiss,
    '결승': l.stageFinal,
  };

  for (final entry in stageMap.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }

  return result;
}
