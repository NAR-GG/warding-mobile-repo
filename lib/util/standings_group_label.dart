import '../l10n/app_localizations.dart';

/// 순위표 그룹 이름([StandingGroup.name])을 화면에 쓸 표시명으로 바꾼다.
///
/// 서버는 표시용 문구가 아니라 코드에 가까운 값을 준다(실측 2026-10-06):
/// LCK 는 `LEGEND`·`RISE`, ASIAN_GAMES 는 `A`·`B`. 그대로 그리면 순위표 헤더에
/// "LEGEND", 더보기 버튼에 "B 1팀 더보기" 처럼 뜬다.
///
/// - 아는 코드(`LEGEND`·`RISE`)는 한국어 그룹명으로 바꾼다.
/// - 한두 글자 그룹 기호(`A`·`B`·`1`)는 앞에 "그룹"을 붙여 "그룹 A" 로 만든다.
/// - 그 밖(이미 사람이 읽을 문구거나 처음 보는 값)은 **그대로 둔다** — 모르는
///   리그가 새로 열려도 최소한 서버 값이 보이게 하려는 것이다.
/// - 빈 문자열이면 null 을 준다(호출부가 자리를 비우거나 자체 폴백을 쓴다).
String? standingsGroupLabel(String name, AppLocalizations l) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;

  switch (trimmed.toUpperCase()) {
    case 'LEGEND':
      return l.homeStandingsLegendGroup;
    case 'RISE':
      return l.homeStandingsRiseGroup;
  }

  // "A"·"B"·"1" 처럼 영숫자 기호 하나만 온 경우 — 그것만 띄우면 무슨 값인지
  // 알 수 없어 "그룹 A" 로 만든다. 한글은 제외한다("결승" 같은 두 글자 이름이
  // "그룹 결승" 이 되면 안 된다).
  if (RegExp(r'^[A-Za-z0-9]$').hasMatch(trimmed)) {
    return '${l.stageGroup} ${trimmed.toUpperCase()}';
  }
  return trimmed;
}
