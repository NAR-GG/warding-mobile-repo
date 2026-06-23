import '../config/api_config.dart';

/// 백엔드가 상대경로(`/images/...`)로 주는 이미지 URL에 API 호스트를 붙인다.
///
/// 절대 URL(`http...`)·`null`·빈 문자열은 그대로 둔다. 따라서 ddragon 같은
/// 외부 절대 URL 에 적용해도 안전하다(변경 없이 반환).
///
/// 예) `/images/players/Zeus_제우스.webp` → `https://api.nar.kr/images/players/Zeus_제우스.webp`
String? resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  if (url.startsWith('/')) return '${ApiConfig.host}$url';
  return url;
}

/// 챔피언 영문 키로 Data Dragon 스플래시 아트 URL 을 만든다(배경용).
/// 스플래시 경로는 버전이 없어 패치와 무관하게 동작한다.
///
/// 예) 'Vayne' → 'https://ddragon.leagueoflegends.com/cdn/img/champion/splash/Vayne_0.jpg'
/// 이름이 비어 있으면 null 을 반환한다.
String? championSplashUrl(String championName) {
  if (championName.isEmpty) return null;
  return 'https://ddragon.leagueoflegends.com/cdn/img/champion/splash/'
      '${championName}_0.jpg';
}
