/// 웹뷰 안에서 누른 링크를 **웹뷰가 받을지, 바깥 브라우저로 보낼지** 정한다.
///
/// **왜 필요한가.** 네비게이션 델리게이트에 아무 규칙이 없으면 외부 링크가
/// 웹뷰 **안에서** 열린다. 그러면 사용자는 구글폼·외부 사이트에 갇히고,
/// 네이티브 헤더가 없으니 앱으로 돌아올 길이 없다. 공지 상세의 '자세히
/// 보기'(`actionUrl`)와 광고 안내의 신청 버튼이 그 자리다.
///
/// **판정은 호스트로 한다.** 우리 웹 호스트면 웹뷰가 받고(화면 간 이동),
/// 아니면 바깥으로 보낸다. 경로 목록으로 가르지 않는 이유는 웹에 화면이
/// 늘 때마다 네이티브를 같이 고쳐야 하기 때문이다 — 호스트 기준이면 웹이
/// 무슨 화면을 추가하든 네이티브는 그대로다.
library;

/// `url` 을 웹뷰 안에서 열어도 되는가.
///
/// [webHost] 는 `ApiConfig.webViewHost` 처럼 스킴을 포함한 주소다
/// (`http://localhost:3100`·`https://m.nar.kr`). 로컬 개발과 운영에서 호스트가
/// 다르므로 상수로 박지 않고 받는다.
///
/// 판정 규칙:
/// - 호스트가 같으면 **안에서** 연다 (웹 화면 간 이동)
/// - `http`·`https` 가 아니면 **바깥으로** 보낸다 (`mailto:`·`tel:`·앱 스킴)
/// - 그 밖의 외부 주소는 **바깥으로** 보낸다
/// - 파싱되지 않는 주소는 **안에서** 연다 — 웹뷰가 알아서 거절하게 두는
///   편이, 못 읽는 주소를 외부 브라우저에 떠넘기는 것보다 조용하다
bool shouldOpenInWebView(String url, {required String webHost}) {
  final target = Uri.tryParse(url);
  if (target == null) return true;

  // 상대 경로(`/community/post/1`)는 호스트가 비어 있다. 웹 안의 이동이다.
  if (!target.hasAuthority) {
    return target.scheme.isEmpty || _isHttp(target.scheme);
  }

  if (!_isHttp(target.scheme)) return false;

  final host = Uri.tryParse(webHost);
  if (host == null) return false;

  // 포트까지 본다 — 로컬 개발은 `localhost:3100` 이고, 같은 호스트의 다른
  // 포트는 우리 웹이 아니다.
  return target.host == host.host && target.port == host.port;
}

bool _isHttp(String scheme) => scheme == 'http' || scheme == 'https';
