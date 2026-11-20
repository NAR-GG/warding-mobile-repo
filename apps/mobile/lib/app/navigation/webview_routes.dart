/// 웹으로 간 화면의 **단일 출처**.
///
/// 어느 화면이 웹으로 갔는지 한 파일에서 보인다. 네이티브 화면 단위와 웹
/// 라우트가 **1:1이어야** 뒤로가기가 어긋나지 않는다 — 웹 안에서 자유롭게
/// 라우팅하면 네이티브 스택과 틀어진다.
library;

import 'package:warding/core/config/api_config.dart';

/// 전환된 화면 한 건.
class WebRoute {
  const WebRoute({required this.path, required this.stage});

  /// 웹 경로. 호스트를 뺀 부분이다.
  final String path;

  /// 이 화면이 요구하는 브리지 단계. 네이티브가 무엇을 준비해야 하는지 보인다.
  final BridgeStage stage;

  /// 전체 URL.
  String url({Map<String, String> params = const {}}) {
    var p = path;
    params.forEach((k, v) => p = p.replaceAll(':$k', Uri.encodeComponent(v)));
    return '${ApiConfig.webViewHost}$p';
  }
}

/// 브리지 단계. 뒤 단계는 앞 단계를 포함한다.
enum BridgeStage {
  /// 웹 → 네이티브 단방향만 쓴다.
  a,

  /// 네이티브 → 웹 브로드캐스트까지 쓴다(로그인 상태 반영 등).
  b,

  /// 양방향 호출까지 쓴다(사진 뷰어·공유).
  c,
}

/// 커뮤니티 글 목록.
///
/// 웹이 가져가는 것은 **목록 본문뿐이다** — 하단 탭·알림 벨·검색·글쓰기 FAB 는
/// 앱 셸이라 네이티브에 남는다. 웹뷰가 탭을 그리면 네이티브 탭과 두 겹이 된다.
///
/// 목록 → 상세가 둘 다 웹이라 항목 탭은 브리지를 거치지 않고 웹 안에서
/// 이동한다. 그래서 읽기 전용이고 Stage A 로 충분하다.
const communityListRoute = WebRoute(path: '/community', stage: BridgeStage.a);

/// 커뮤니티 검색.
///
/// 뒤로가기만 네이티브에 위임하므로 Stage A 다. 결과 카드를 탭하면 상세로
/// 가는데 그것도 웹이라 브리지를 거치지 않는다.
const communitySearchRoute = WebRoute(path: '/community/search', stage: BridgeStage.a);

/// 커뮤니티 글쓰기.
///
/// 사진 첨부는 `<input type="file">` 로 한다 — iOS 는 WKWebView 가 파일 선택
/// 패널을 자체 처리하고, Android 는 `WardingWebView` 가 등록한
/// `setOnShowFileSelector` 가 받는다. 그래서 브리지 단계는 뒤로가기만 쓰는
/// Stage A 다.
const communityWriteRoute = WebRoute(path: '/community/write', stage: BridgeStage.a);

/// 커뮤니티 글 상세. 사진 뷰어를 네이티브로 열어 Stage C 를 쓴다.
const communityPostRoute = WebRoute(path: '/community/post/:id', stage: BridgeStage.c);

/// 공지 목록. 마이페이지 '공지사항' 행에서 진입한다.
///
/// 목록 → 상세가 둘 다 웹이라 항목 탭은 브리지를 거치지 않는다. 뒤로가기만
/// 네이티브에 위임하므로 Stage A 다.
const noticeListRoute = WebRoute(path: '/notice', stage: BridgeStage.a);

/// 공지 상세. 읽기 전용이라 Stage A 로 충분하다.
const noticeRoute = WebRoute(path: '/notice/:id', stage: BridgeStage.a);

/// 전환된 화면 전체. 배포 파이프라인의 브리지 계약 가드가 읽는 목록이다.
const webviewRoutes = <WebRoute>[
  communityListRoute,
  communitySearchRoute,
  communityWriteRoute,
  communityPostRoute,
  noticeListRoute,
  noticeRoute,
];
