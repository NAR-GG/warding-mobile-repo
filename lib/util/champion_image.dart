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
  /// [imageUrl] 이 있으면 [_toPortrait] 로 카드 비율에 맞는 변형을 고르고,
  /// 없으면 [championName] 으로 Data Dragon 폴백 URL 을 만든다. 둘 다 없으면 null.
  static String? resolve(String? imageUrl, String? championName) {
    if (imageUrl != null && imageUrl.isNotEmpty) return _toPortrait(imageUrl);
    return ddragonUrl(championName);
  }

  /// CommunityDragon 스플래시 아트 URL 을 같은 챔피언의 `portrait` 변형으로
  /// 바꾼다. 해당 형태가 아니면 그대로 둔다.
  ///
  /// 서버는 챔피언 픽·밴 이미지를 `.../champion/<id>/splash-art/centered` 로
  /// 내려주는데, 이건 1280×720 **가로형** 스플래시(약 99KB)다. 그런데 앱에서
  /// 이 이미지가 놓이는 자리는 60×101 **세로** 칸이라, `BoxFit.cover` 가 가로를
  /// 잘라내며 챔피언이 크게 확대된다. 한 세트에 10장이라 용량도 1MB 가까이 된다.
  ///
  /// 같은 CDN 이 제공하는 변형 중 카드 비율에 가장 가까운 것을 고른다.
  ///
  /// | 변형 | 크기 | 세로/가로 | 용량 |
  /// |---|---|---|---|
  /// | splash-art/centered | 1280×720 | 0.56 | 99KB |
  /// | square | 128×128 | 1.00 | 30KB |
  /// | **portrait** | **308×560** | **1.82** | **46KB** |
  ///
  /// 카드는 60×101 이라 1.68 이다 — `portrait`(1.82)가 거의 일치해 잘림이
  /// 최소이고, 용량도 절반이 된다. `square` 는 더 가볍지만 정사각이라 세로로
  /// 68% 확대돼 얼굴이 잘려 나간다.
  ///
  /// 경로만 갈아끼우므로 서버가 나중에 다른 변형을 주기 시작하면 이 함수는
  /// 자연히 지나친다(형태가 안 맞으면 원본 반환).
  static String _toPortrait(String url) {
    const marker = '/splash-art';
    final index = url.indexOf(marker);
    if (index < 0) return url;
    // '/splash-art' 뒤에 오는 것(`/centered` 등)까지 통째로 대체한다.
    return '${url.substring(0, index)}/portrait';
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
