import 'package:flutter/widgets.dart';

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

/// 표시 크기에 맞는 디코딩 가로폭([CachedNetworkImage.memCacheWidth])을 구한다.
///
/// 이미지가 차지하는 메모리는 **표시 크기가 아니라 디코딩된 해상도**로 정해진다
/// (가로×세로×4바이트). 400×600 짜리를 38 칸에 그려도 0.92MB 를 그대로 쓴다.
/// 챔피언 픽 탭처럼 한 화면에 20장이 깔리면 18MB 가 된다.
///
/// [boxWidth]·[boxHeight] 는 이미지가 놓이는 **칸의 논리 크기**다.
/// `BoxFit.cover` 는 칸을 채우려고 원본을 확대하기도 하므로, 세로가 모자라
/// 확대되는 만큼까지 고려해 가로폭을 정한다 — 칸 너비만 보고 자르면 세로로
/// 늘어나며 흐려진다.
///
/// [sourceWidth]·[sourceHeight] 는 원본 해상도다. 서버가 카드 비율에 맞춰
/// 주는 챔피언 이미지는 400×600 이다.
///
/// 원본보다 큰 값은 의미가 없으므로(확대 저장) 원본 크기로 자른다.
int decodeWidthFor(
  BuildContext context, {
  required double boxWidth,
  required double boxHeight,
  required int sourceWidth,
  required int sourceHeight,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final needW = boxWidth * dpr;
  final needH = boxHeight * dpr;
  // cover 배율 — 가로·세로 중 더 많이 키워야 하는 쪽을 따른다.
  final scale = (needW / sourceWidth) > (needH / sourceHeight)
      ? needW / sourceWidth
      : needH / sourceHeight;
  final width = (sourceWidth * scale).ceil();
  return width > sourceWidth ? sourceWidth : width;
}

/// 커뮤니티 첨부 사진에 쓰는 표시 폭 버킷(논리 px 아님, **실제 픽셀**).
///
/// 임의의 폭을 그대로 URL 에 넣으면 폭 하나마다 Cloudinary 파생 에셋이 새로 만들어진다.
/// 기기 해상도가 제각각이라 그대로 두면 사진 한 장이 수십 벌로 늘어나 변환 쿼터를 태운다.
/// 몇 개 버킷으로 반올림해 캐시 적중률을 지킨다.
const List<int> kCloudinaryWidthBuckets = [200, 400, 800, 1200];

/// Cloudinary **업로드** URL 에 표시용 변환을 끼운다.
///
/// 커뮤니티 첨부는 서버가 변환 없는 `secure_url` 을 그대로 저장한다(원본 보존). 그래서
/// 앱이 원본 해상도(아이폰 4032×3024, 수 MB)를 통째로 받아 200px 칸에 그리고 있었다.
/// 표시 직전에 폭을 깎아 전송량과 디코딩 메모리를 함께 줄인다 — 저장된 원본은 그대로다.
///
/// ```
/// .../image/upload/v1788008914/community/12/xxx.jpg
/// .../image/upload/f_webp,q_auto,w_800/v1788008914/community/12/xxx.jpg
/// ```
///
/// `c_limit` 은 원본보다 크게 늘리지 않는다는 뜻이다 — 작은 사진을 확대해 흐려지는 걸 막는다.
///
/// Cloudinary 업로드 URL 이 아니면 그대로 돌려준다(팀 로고처럼 서버가 이미 변환을 붙여
/// 주는 `image/fetch/` URL 도 여기 해당해 두 번 변환되지 않는다).
String? cloudinaryScaled(String? url, {required int targetPixelWidth}) {
  if (url == null || url.isEmpty) return url;
  const marker = '/image/upload/';
  final at = url.indexOf(marker);
  if (at < 0 || !url.startsWith('https://res.cloudinary.com/')) return url;

  final rest = url.substring(at + marker.length);
  // 이미 변환이 끼어 있으면(예: 재호출) 건드리지 않는다. 버전 세그먼트(v123...)로 시작해야
  // 변환이 없는 원본 URL 이다.
  if (!RegExp(r'^v\d+/').hasMatch(rest)) return url;

  final width = kCloudinaryWidthBuckets.firstWhere(
    (b) => b >= targetPixelWidth,
    orElse: () => kCloudinaryWidthBuckets.last,
  );
  return '${url.substring(0, at + marker.length)}f_webp,q_auto,w_$width,c_limit/$rest';
}

/// Data Dragon 스플래시 아트의 해상도. 챔피언과 무관하게 고정이다.
const int kChampionSplashWidth = 1215;
const int kChampionSplashHeight = 717;

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
