/// 드래곤 속성(한국어 라벨) → 로컬 에셋 매핑.
///
/// 백엔드가 내려주는 속성명은 한국어 문자열이다(예: '바람', '화염').
/// `MatchLiveEvent.subType`(라이브 이벤트)과 `TeamObjectives.dragonTypes`
/// (챔피언 픽 응답의 오브젝트 집계) 양쪽에서 같은 형식을 쓴다.
String dragonAssetFor(String? subType) {
  final s = subType?.trim() ?? '';
  if (s.contains('바람') || s.toLowerCase().contains('cloud')) {
    return 'assets/images/cloud-dragon.png';
  }
  if (s.contains('바다') || s.toLowerCase().contains('ocean')) {
    return 'assets/images/ocean-dragon.png';
  }
  if (s.contains('대지') ||
      s.contains('산') ||
      s.toLowerCase().contains('mountain')) {
    return 'assets/images/mountain-dragon.png';
  }
  if (s.contains('화염') ||
      s.contains('불') ||
      s.toLowerCase().contains('infernal')) {
    return 'assets/images/infernal-dragon.png';
  }
  if (s.contains('마법공학') || s.toLowerCase().contains('hextech')) {
    return 'assets/images/hextech-dragon.png';
  }
  if (s.contains('화학공학') || s.toLowerCase().contains('chemtech')) {
    return 'assets/images/chemtech-dragon.png';
  }
  if (s.contains('장로') || s.toLowerCase().contains('elder')) {
    return 'assets/images/elder-dragon.png';
  }
  // 속성 미상이면 기본 드래곤 아이콘.
  return 'assets/images/cloud-dragon.png';
}
