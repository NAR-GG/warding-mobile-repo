/// 진행 중인 솔랭 판의 경과 시간 계산·표기.
///
/// 서버가 주는 `elapsedSeconds` 는 **조회 시점 스냅샷**이라 그대로 두면
/// 화면에서 멈춰 보인다. `startedAt` 이 있으면 기기 시계로 다시 계산해
/// 매초 올라가게 한다. 홈 솔랭 카드와 내 선수 목록이 같은 규칙을 써야
/// 같은 판이 두 화면에서 다른 시간으로 보이지 않는다.
library;

/// [startedAt] 이 있으면 지금 시각으로 경과를 다시 계산한다.
///
/// 스냅샷([snapshotSeconds])보다 작아지는 경우는 쓰지 않는다 — 기기 시계가
/// 서버보다 뒤처져 있으면 시간이 거꾸로 가는 것처럼 보인다.
int liveElapsedSeconds({required int snapshotSeconds, DateTime? startedAt}) {
  if (startedAt == null) return snapshotSeconds;
  final seconds = DateTime.now().difference(startedAt).inSeconds;
  return seconds > snapshotSeconds ? seconds : snapshotSeconds;
}

/// 경과 시간 "m:ss". 1시간이 넘으면 "h:mm:ss".
String formatElapsed(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}
