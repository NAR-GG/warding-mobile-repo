/// 오프셋이 없는 시각은 KST 로 본다 — 뉴스·한줄평 `createdAt` 이 `2026-09-16T22:19:16`
/// 꼴이다. 솔랭 시각은 `+09:00` 이 붙어 온다. 파싱에 실패하면 null.
DateTime? parseServerTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final hasOffset = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
  return DateTime.tryParse(hasOffset ? raw : '$raw+09:00');
}

/// [at] 부터 [now] 까지 지난 분. null 이거나 미래면 0.
///
/// 서버 시각을 "N분 전" 으로 보여주는 자리가 여럿이라(솔랭 종료·평점 작성·뉴스
/// 발행) 여기 둔다. 음수 clamp 는 기기 시계가 서버보다 앞설 때를 막는다.
int minutesSince(DateTime? at, DateTime now) =>
    at == null ? 0 : now.difference(at).inMinutes.clamp(0, 1 << 30);
