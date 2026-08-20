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
