/// 서버 `matchStatus` 문자열 판정 유틸.
///
/// 값 표기가 화면·API 마다 흔들려서(`inProgress` / `in_progress` / `LIVE` /
/// `진행 중`) 완전일치로 비교하면 조용히 놓친다. 실제로 경기리스트·경기 일정이
/// `s == 'in_progress'` 로 비교하는 바람에, 서버가 내려주는 `inProgress`
/// (카멜케이스, 밑줄 없음)를 못 잡아 진행 중인데도 LIVE 배지가 안 떴다.
/// 그래서 부분 일치(contains)로 통일해 한 곳에서만 관리한다.
library;

/// [status] 가 라이브(진행 중)를 뜻하는지. 대소문자·밑줄 표기를 모두 흡수한다.
///
/// 예: `live`, `LIVE`, `inProgress`, `in_progress`, `ongoing`, `진행 중`.
bool isLiveMatchStatus(String status) {
  final s = status.toLowerCase();
  return s.contains('live') ||
      s.contains('inprogress') ||
      s.contains('in_progress') ||
      s.contains('ongoing') ||
      status.contains('진행');
}

/// 진행 중인 세트 번호(1부터). 경기리스트·경기 일정의 'SET N 진행중' 라벨용.
///
/// 리스트 API(`/api/mobile/schedules`)는 상세처럼 세트별 진행 상태를 주지 않는다.
/// `ScheduleMatch.sets` 는 VOD 가 있는 세트만 담긴 목록이라(진행 중인 세트는 VOD 가
/// 아직 없어 빠진다) 그 길이를 세트 번호로 쓰면 실제보다 작게 나온다 — SET 2 진행
/// 중인데 "SET 1 진행중" 으로 뜨던 원인이다.
///
/// 대신 양 팀 세트 승수의 합을 쓴다. 합 = 이미 끝난 세트 수이므로 진행 중인 세트는
/// 그 다음 번호다. VOD 가 승수보다 많이 잡히는 경우(집계 지연 등)에 대비해
/// [setsPlayed] 와 비교해 큰 쪽을 택한다.
int liveSetNumber({
  required int homeScore,
  required int awayScore,
  int setsPlayed = 0,
}) {
  final endedSets = homeScore + awayScore;
  final base = endedSets > setsPlayed ? endedSets : setsPlayed;
  return (base + 1).clamp(1, 99);
}
