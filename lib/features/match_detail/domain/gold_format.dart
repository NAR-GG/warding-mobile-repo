/// 골드 숫자를 "78.6k" 형식으로 축약한다. 1000 미만이면 그대로 정수 표시.
String formatGold(int gold) {
  if (gold < 1000) return '$gold';
  return '${(gold / 1000).toStringAsFixed(1)}k';
}
