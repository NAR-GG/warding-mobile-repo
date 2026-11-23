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

/// 마이페이지 "내 활동" — 내가 쓴 글·내가 쓴 댓글·스크랩.
///
/// **탭이 경로로 갈린다**(`:tab` = `posts`·`comments`·`scraps`). 네이티브는
/// 한 화면 안의 `PageView` 였고 진입점 3개가 초기 탭만 달리 줬는데, 웹은
/// 그 셋이 URL 3개와 1:1 로 맞는다 — 각 탭이 자기 데이터를 SSR 로 그린다.
/// 대신 **스와이프 전환이 빠진다**(감수한 차이다).
///
/// 항목을 누르면 커뮤니티 글 상세로 가는데 그것도 웹이라 브리지를 거치지
/// 않는다. 뒤로가기만 위임하므로 Stage A 다.
const myActivityRoute = WebRoute(path: '/my-activity/:tab', stage: BridgeStage.a);

/// 공지 목록. 마이페이지 '공지사항' 행에서 진입한다.
///
/// 목록 → 상세가 둘 다 웹이라 항목 탭은 브리지를 거치지 않는다. 뒤로가기만
/// 네이티브에 위임하므로 Stage A 다.
const noticeListRoute = WebRoute(path: '/notice', stage: BridgeStage.a);

/// 공지 상세. 읽기 전용이라 Stage A 로 충분하다.
const noticeRoute = WebRoute(path: '/notice/:id', stage: BridgeStage.a);

/// 광고 안내. 마이페이지 '광고 안내' 행과 응원 광고 상세에서 진입한다.
///
/// **본문은 공지 상세와 같은 것을 그린다** — 백오피스가 `slug=ad-guide`
/// 공지로 관리하고, 네이티브도 `AdGuideScreen` 이 `NoticeDetailScreen` 을
/// 재사용했다. 그래서 경로에 slug 를 받지 않고 고정이다(진입점 둘 다
/// 인자가 없다).
///
/// 하단 '광고 신청하기' 는 구글폼이라 **바깥 브라우저로 나간다.** 웹이
/// `<a>` 로 두면 네이티브의 호스트 판정(`shouldOpenInWebView`)이 걸러내므로
/// 브리지를 쓰지 않는다 — 그래서 뒤로가기만 위임하는 Stage A 다.
const adGuideRoute = WebRoute(path: '/ad-guide', stage: BridgeStage.a);

/// 마이페이지 '내 리뷰/평점'. 내가 작성한 평가 목록이다.
///
/// 항목의 '리뷰보기' 가 선수 평점으로 가는데 **그것도 웹이라 브리지를
/// 거치지 않는다** — 네이티브는 `PlayerRatingScreen` 에 인자를 8개 넘겨야
/// 했는데, 웹은 URL 두 조각이면 상세가 나머지를 스스로 받는다.
///
/// 삭제가 있지만 웹이 서버 액션으로 처리한다. 뒤로가기만 위임하므로
/// Stage A 다.
const myReviewRoute = WebRoute(path: '/my-review', stage: BridgeStage.a);

/// 선수 평점 상세. 내 평점 목록의 '리뷰보기' 에서 들어온다.
///
/// **비회원 조회가 열려 있다**(실측 2026-11-23, HTTP 200). 작성·삭제는
/// 로그인이 필요한데, **웹에 로그인 화면이 없어**(카카오·네이버 SDK 가
/// 네이티브에 있다) 그 한 건만 `navigate('login')` 으로 네이티브를 부른다.
/// 그래서 Stage A 다.
const playerRatingRoute = WebRoute(
  path: '/rating/:gameId/:participantId',
  stage: BridgeStage.a,
);

/// 커뮤니티 알림함. 커뮤니티 헤더의 벨에서 진입한다.
///
/// **이 화면이 웹으로 오면서 브리지가 하나 줄었다** — 벨이
/// `requestNavigate('notification')` 로 네이티브를 부르던 것이 웹 안의
/// 이동(`<Link>`)이 됐다. `kNativeRoutes` 의 `notification` 은 구버전 앱이
/// 보내올 수 있어 남겨 둔다.
///
/// 커뮤니티 알림만 다룬다(`group=COMMUNITY`) — 경기 알림은 마이구독
/// 피드가 담당한다. 뒤로가기만 위임하므로 Stage A 다.
const notificationsRoute = WebRoute(path: '/notifications', stage: BridgeStage.a);

/// 전환된 화면 전체. 배포 파이프라인의 브리지 계약 가드가 읽는 목록이다.
const webviewRoutes = <WebRoute>[
  communityListRoute,
  communitySearchRoute,
  communityWriteRoute,
  communityPostRoute,
  myActivityRoute,
  noticeListRoute,
  noticeRoute,
  adGuideRoute,
  myReviewRoute,
  playerRatingRoute,
  notificationsRoute,
];
