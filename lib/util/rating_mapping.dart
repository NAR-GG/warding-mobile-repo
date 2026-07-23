import '../components/nar_badge.dart';
import '../l10n/app_strings.dart';

/// 백엔드 teamSide('BLUE'/'RED') → UI 진영 뱃지.
BadgeSide sideFromTeamSide(String teamSide) =>
    teamSide.toUpperCase() == 'RED' ? BadgeSide.red : BadgeSide.blue;

/// 백엔드 role 코드 → 현재 언어의 포지션 라벨. 모르는 값은 원본 유지.
String positionFromRole(String role) {
  switch (role.toUpperCase()) {
    case 'TOP':
      return appStrings?.laneTop ?? 'Top';
    case 'JUNGLE':
      return appStrings?.laneJungle ?? 'Jungle';
    case 'MID':
    case 'MIDDLE':
      return appStrings?.laneMid ?? 'Mid';
    case 'BOTTOM':
    case 'BOT':
    case 'ADC':
      return appStrings?.laneBot ?? 'ADC';
    case 'SUPPORT':
    case 'UTILITY':
      return appStrings?.laneSupport ?? 'Support';
    default:
      return role;
  }
}

/// 작성 시각 → 상대 시간 표기. 7일 이상은 'YYYY.MM.DD'.
/// [now] 는 테스트용 주입(미지정 시 DateTime.now()).
String ratingTimeAgo(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return appStrings?.justNow ?? 'Just now';
  if (diff.inMinutes < 60) return appStrings?.minutesAgo(diff.inMinutes) ?? '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return appStrings?.hoursAgo(diff.inHours) ?? '${diff.inHours}h ago';
  if (diff.inDays < 7) return appStrings?.daysAgo(diff.inDays) ?? '${diff.inDays}d ago';
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '${time.year}.$m.$d';
}
