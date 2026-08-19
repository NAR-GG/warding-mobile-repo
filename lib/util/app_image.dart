import '../config/api_config.dart';

/// 백엔드가 상대경로(`/images/...`)로 주는 이미지 URL에 API 호스트를 붙이고,
/// 평문 `http://` 는 `https://` 로 올린다.
///
/// `null`·빈 문자열은 그대로 둔다.
///
/// 예) `/images/players/Zeus_제우스.webp` → `https://api.nar.kr/images/players/Zeus_제우스.webp`
///
/// **https 승격이 필요한 이유**: 선수 이미지 URL 이 `http://static.lolesports.com/...`
/// 로 내려온다(팀 로고는 https 다). iOS 는 ATS 로 평문 HTTP 를 막고, 지금은
/// 서버가 301 로 https 에 넘겨줘서 겨우 살아 있는데 — 그 리다이렉트가 이미지
/// **한 장마다 왕복 한 번**이다. 목록에 수십 장이 뜨는 화면에서는 그만큼
/// 그대로 지연이 된다. 호스트는 이미 https 를 제공하므로 처음부터 그리로 보낸다.
String? resolveImageUrl(String? url) {
  if (url == null || url.isEmpty) return url;
  if (url.startsWith('/')) return '${ApiConfig.host}$url';
  if (url.startsWith('http://')) {
    return 'https://${url.substring('http://'.length)}';
  }
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
