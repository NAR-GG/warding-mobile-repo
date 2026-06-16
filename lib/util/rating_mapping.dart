import '../components/nar_badge.dart';

/// 백엔드 teamSide('BLUE'/'RED') → UI 진영 뱃지.
BadgeSide sideFromTeamSide(String teamSide) =>
    teamSide.toUpperCase() == 'RED' ? BadgeSide.red : BadgeSide.blue;

/// 백엔드 role 코드 → 한글 포지션 라벨. 모르는 값은 원본 유지.
String positionFromRole(String role) {
  switch (role.toUpperCase()) {
    case 'TOP':
      return '탑';
    case 'JUNGLE':
      return '정글';
    case 'MID':
    case 'MIDDLE':
      return '미드';
    case 'BOTTOM':
    case 'BOT':
    case 'ADC':
      return '원딜';
    case 'SUPPORT':
    case 'UTILITY':
      return '서폿';
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
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '${time.year}.$m.$d';
}
