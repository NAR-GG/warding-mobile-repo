/// 서버가 내려주는 챔피언 이미지의 해상도.
///
/// Cloudinary 변환(`w_400,h_600,c_fill,g_auto`)으로 고정돼 있다. 디코딩 폭을
/// 계산할 때 원본 크기가 필요해서 상수로 둔다 — 서버 변환이 바뀌면 여기만 고친다.
const int kChampionImageWidth = 400;
const int kChampionImageHeight = 600;

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
  /// [imageUrl] 이 있으면 **그대로** 쓰고, 없으면 [championName] 으로 Data
  /// Dragon 폴백 URL 을 만든다. 둘 다 없으면 null.
  ///
  /// 예전에는 여기서 CommunityDragon 의 `/splash-art/centered` 를 `/portrait`
  /// 로 바꿔 받았다. 서버가 1280×720 가로형 스플래시(약 99KB)를 내려주는데
  /// 앱에서 그 이미지가 놓이는 자리는 60×101 세로 칸이라, 비율이 안 맞고
  /// 한 세트 10장이면 1MB 가까이 됐기 때문이다.
  ///
  /// 지금은 서버가 Cloudinary 를 거쳐 내려준다
  /// (`.../image/fetch/f_webp,q_auto,w_400,h_600,c_fill,g_auto/...`).
  /// 카드 비율에 맞는 400×600 으로 이미 잘려 오고, `g_auto` 가 인물 위치까지
  /// 잡아 준다. 그래서 경로를 갈아끼우면 오히려 손해다.
  ///
  /// | | 10장 합계 | TTFB |
  /// |---|---|---|
  /// | **서버 URL 그대로** | **158KB** | **0.16s** |
  /// | `/portrait` 로 rewrite | 179KB | 1.13s |
  ///
  /// rewrite 한 주소는 Cloudinary 에 캐시된 변형이 아니라서 매번 원본을 새로
  /// 받아 변환한다 — 그래서 더 크고 더 느리다.
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
