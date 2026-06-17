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
