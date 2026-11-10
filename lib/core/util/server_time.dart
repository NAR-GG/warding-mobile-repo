/// 오프셋이 없는 시각은 KST 로 본다 — 뉴스·한줄평 `createdAt` 이 `2026-09-16T22:19:16`
/// 꼴이다. 솔랭 시각은 `+09:00` 이 붙어 온다. 파싱에 실패하면 null.
DateTime? parseServerTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final hasOffset = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
  return DateTime.tryParse(hasOffset ? raw : '$raw+09:00');
}
