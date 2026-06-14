/// 챔피언 이미지 URL 보정 유틸.
///
/// 백엔드가 [championImageUrl] 을 내려주면 그대로 쓰고, null/빈값이면 영어
/// 챔피언명으로 Data Dragon 폴백 URL 을 만든다.
class ChampionImage {
  ChampionImage._();

  /// Data Dragon 챔피언 아이콘 버전.
  static const String _ddragonVersion = '15.13.1';

  /// 챔피언 이미지 URL 을 해석한다.
  ///
  /// [imageUrl] 이 있으면 그대로 반환하고, 없으면 [championName] 으로 Data Dragon
  /// 폴백 URL 을 만든다. 둘 다 없으면 null.
  static String? resolve(String? imageUrl, String? championName) {
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    return ddragonUrl(championName);
  }

  /// Data Dragon 키가 단순 "공백·아포스트로피 제거" 규칙과 다른 챔피언 예외 표.
  /// (영어명 → 파일명 키)
  static const Map<String, String> _keyExceptions = {
    "Kai'Sa": 'Kaisa',
    "Cho'Gath": 'Chogath',
    "Kha'Zix": 'Khazix',
    "Vel'Koz": 'Velkoz',
    "Bel'Veth": 'Belveth',
    "K'Sante": 'KSante',
    "Rek'Sai": 'RekSai',
    "LeBlanc": 'Leblanc',
    'Wukong': 'MonkeyKing',
    'Nunu & Willump': 'Nunu',
    'Renata Glasc': 'Renata',
  };

  /// 영어 챔피언명으로 Data Dragon 아이콘 URL 을 만든다.
  ///
  /// 알려진 예외는 [_keyExceptions] 를 따르고, 그 외에는 공백·아포스트로피·점을
  /// 제거한 이름을 키로 쓴다. 예) "Rumble" → "Rumble".
  static String? ddragonUrl(String? championName) {
    if (championName == null || championName.isEmpty) return null;
    final key = _ddragonKey(championName);
    if (key.isEmpty) return null;
    return 'https://ddragon.leagueoflegends.com/cdn/$_ddragonVersion/img/champion/$key.png';
  }

  /// 백엔드 영어 챔피언명 → Data Dragon 파일명 키.
  static String _ddragonKey(String name) {
    final exception = _keyExceptions[name];
    if (exception != null) return exception;
    // 기본 규칙: 공백·아포스트로피·점 제거.
    return name.replaceAll(RegExp(r"[ '’.&]"), '');
  }
}
