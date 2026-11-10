import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 쇼츠 카드가 외부로 열 주소. https 만 허용한다 — 서버가 준 값이라
/// `javascript:`·`intent:`·`file:` 같은 스킴이나 깨진 주소는 열지 않는다.
/// 열 수 없으면 null.
Uri? shortsLaunchUri(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

/// 유튜브 앱·브라우저로 연다. 열 수 없으면 조용히 로그만 남긴다.
Future<void> openShortsExternally(String url) async {
  final uri = shortsLaunchUri(url);
  if (uri == null) {
    debugPrint('[Shorts] 주소가 https 가 아니라 열지 않음: $url');
    return;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) debugPrint('[Shorts] 열기 실패: $uri');
  } catch (e) {
    debugPrint('[Shorts] 열기 실패: $e');
  }
}
