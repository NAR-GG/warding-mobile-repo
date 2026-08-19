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
  /// [imageUrl] 이 있으면 [_toSquare] 로 얼굴이 중앙에 오는 변형을 고르고,
  /// 없으면 [championName] 으로 Data Dragon 폴백 URL 을 만든다. 둘 다 없으면 null.
  static String? resolve(String? imageUrl, String? championName) {
    if (imageUrl != null && imageUrl.isNotEmpty) return _toSquare(imageUrl);
    return ddragonUrl(championName);
  }

  /// CommunityDragon 스플래시 아트 URL 을 같은 챔피언의 `square` 변형으로
  /// 바꾼다. 해당 형태가 아니면 그대로 둔다.
  ///
  /// 서버는 챔피언 픽·밴 이미지를 `.../champion/<id>/splash-art/centered` 로
  /// 내려주는데, 이건 1280×720 **가로형** 스플래시(약 99KB)다. 앱에서 이
  /// 이미지가 놓이는 자리는 60×101 픽 카드와 36.4 정사각 밴 칸이다.
  ///
  /// 같은 CDN 이 제공하는 변형 중 `square`(챔피언 아이콘)를 쓴다.
  ///
  /// | 변형 | 크기 | 구도 | 용량 |
  /// |---|---|---|---|
  /// | splash-art/centered | 1280×720 | 전신·챔피언마다 제각각 | 99KB |
  /// | portrait | 308×560 | 전신·챔피언마다 제각각 | 46KB |
  /// | **square** | **128×128** | **얼굴 중앙 고정** | **25KB** |
  ///
  /// 비율만 보면 카드(1.68)에 `portrait`(1.82)가 가깝지만, 그건 전신
  /// 일러스트라 60px 폭에 전신이 다 들어가 얼굴이 아주 작게 보인다. 확대해서
  /// 얼굴을 키우려 해도 인물 위치가 챔피언마다 달라(리신·칼리스타는 머리가
  /// 위쪽, 크산테는 아래쪽) 한 배율·정렬로 전부 담을 수 없다 — 어떤 값을 잡아도
  /// 일부 챔피언은 얼굴이 잘린다.
  ///
  /// `square` 는 챔피언 아이콘이라 **모든 챔피언이 얼굴 중앙 구도로 통일**돼
  /// 있다. 시안이 의도한 "얼굴이 카드를 채우는" 그림이 확대·정렬 조정 없이
  /// 나오고, 용량도 가장 작다.
  ///
  /// 경로만 갈아끼우므로 서버가 나중에 다른 변형을 주기 시작하면 이 함수는
  /// 자연히 지나친다(형태가 안 맞으면 원본 반환).
  static String _toSquare(String url) {
    const marker = '/splash-art';
    final index = url.indexOf(marker);
    if (index < 0) return url;
    // '/splash-art' 뒤에 오는 것(`/centered` 등)까지 통째로 대체한다.
    return '${url.substring(0, index)}/square';
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
