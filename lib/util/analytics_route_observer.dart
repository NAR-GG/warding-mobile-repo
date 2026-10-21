import 'package:flutter/material.dart';

import 'analytics.dart';
import 'analytics_events.dart';

/// 화면 전환을 보고 `page_view` 를 쏘는 observer.
///
/// 이 앱은 named route 를 쓰지 않고 `Navigator.push` 로만 화면을 쌓아서,
/// 라우트 기반 자동 추적이 안 되고 `prev_page` 도 자동으로 나오지 않는다.
/// 화면마다 `initState` 에 수동으로 심는 방법도 있지만 두 가지가 걸린다 —
/// 화면이 30개가 넘어 빠뜨리기 쉽고, 하위 화면에서 **뒤로가기로 복귀**할 때는
/// `initState` 가 다시 돌지 않아 설계상 발생해야 하는 `page_view` 를 놓친다.
/// 그래서 Navigator 레벨에서 한 곳으로 모은다.
///
/// 화면 이름은 [RouteSettings.name] 에서 읽는다. 라우트를 만들 때
/// [analyticsRoute] / [tabRoute] 를 쓰면 이름이 함께 붙는다. 이름이 없는
/// 라우트(바텀시트·다이얼로그 등)는 조용히 무시한다.
///
/// 잡지 못하는 경로 2개는 호출부에서 직접 쏜다:
/// - `MatchDetailRouter` 가 **기존 상세를 재사용**하면 라우트가 바뀌지 않아
///   observer 에 아무 콜백도 오지 않는다 → `applyDeepLink` 시점에 수동 발사.
/// - 세션 만료(`AuthService._forceLogout`)는 `pushAndRemoveUntil` 로 스택을
///   비워 직전 라우트가 사라진다 → `entry_point=session_expired` 를 실어
///   호출부에서 발사.
class AnalyticsRouteObserver extends NavigatorObserver {
  /// 전역 인스턴스. `main.dart` 의 `navigatorObservers` 와, 화면 맥락을
  /// 넘기는 호출부가 같은 객체를 봐야 한다.
  static final AnalyticsRouteObserver instance = AnalyticsRouteObserver();

  /// 직전 화면. `prev_page` 로 실린다. 앱 진입 시점에는 직전 화면이 없다.
  String? _currentPage;

  /// 다음 `page_view` 에 한 번만 실을 추가 프로퍼티.
  ///
  /// 화면을 여는 쪽만 아는 맥락(`match_id`, `entry_point` 등)을 observer 로
  /// 넘기는 통로다. push 직전에 넣어 두면 그 화면의 `page_view` 에 합쳐진다.
  Map<String, dynamic>? _pendingProps;

  /// 지금 화면(`location_page`). 호출부가 클릭 이벤트에 실을 때 쓴다.
  String? get currentPage => _currentPage;

  /// 다음에 열리는 화면의 `page_view` 에 [props] 를 함께 싣는다.
  ///
  /// ```dart
  /// AnalyticsRouteObserver.instance.attachNext({
  ///   AnalyticsProp.matchId: matchId,
  ///   AnalyticsProp.entryPoint: AnalyticsEntryPoint.push,
  /// });
  /// ```
  void attachNext(Map<String, dynamic> props) {
    _pendingProps = {...?_pendingProps, ...props};
  }

  /// 스택을 비우는 이동(`pushAndRemoveUntil`) 뒤에 `prev_page` 를 강제로
  /// 맞춘다. 세션 만료처럼 직전 화면이 사라지는 경로에서 쓴다.
  void overridePrevPage(String? page) => _currentPage = page;

  /// 화면별 `page_view` 추가 프로퍼티 공급자.
  ///
  /// `month`·`sort_order`·`login_status` 처럼 **그 화면의 현재 상태**를
  /// 실어야 하는 값이 있다. 진입 때 한 번 넣는 [attachNext] 로는 부족하다 —
  /// 하위 화면에서 복귀할 때도 `page_view` 가 발생하고(설계 문서 2·3·5번),
  /// 그때는 진입 당시 값이 아니라 **지금 값**을 읽어야 한다.
  ///
  /// 화면이 `initState` 에서 등록하고 `dispose` 에서 [removeProvider] 한다.
  final Map<String, Map<String, dynamic> Function()> _providers = {};

  /// [page] 의 `page_view` 에 실을 프로퍼티 공급자를 등록한다.
  void setProvider(String page, Map<String, dynamic> Function() provider) {
    _providers[page] = provider;
  }

  void removeProvider(String page) => _providers.remove(page);

  /// `MaterialApp.home` 으로 띄운 첫 화면은 라우트 이름이 `/` 다. 이 앱의
  /// 첫 화면은 스플래시이므로 그 값으로 바꿔 준다.
  String? _normalize(String? name) => name == '/' ? AnalyticsPage.splash : name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
  }

  /// 탭 전환은 `pushReplacement` 라 push 가 아니라 replace 로 온다.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _track(newRoute);
  }

  /// 하위 화면이 닫혀 이전 화면이 다시 최상단이 될 때. 홈·경기일정·경기리스트
  /// ·커뮤니티는 하위 화면을 `push` 로 열어 스택에 남으므로 이 경로로 복귀한다.
  ///
  /// **닫힌 라우트가 화면일 때만** 복귀로 본다. 바텀시트·다이얼로그
  /// (`showAppBottomSheet`·`showDialog` 등)도 같은 Navigator 에 쌓이는데,
  /// 그것들을 닫을 때까지 복귀로 치면 시트를 여닫을 때마다
  /// `page_view(location_page=X, prev_page=X)` 자기 루프가 쌓인다 — 이 앱은
  /// 정렬·필터·세트·평점 시트를 자주 쓰므로 수가 크게 부푼다.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_isPageRoute(route)) return;
    if (previousRoute != null) _track(previousRoute);
  }

  /// 화면 라우트인지. 이름이 붙어 있으면 화면으로 보고, 없으면 시트·다이얼로그
  /// 처럼 화면이 아닌 라우트로 취급한다([analyticsRoute]·[tabRoute] 만 이름을
  /// 붙이므로 이 구분이 성립한다).
  bool _isPageRoute(Route<dynamic> route) {
    final name = route.settings.name;
    return name != null && name.isNotEmpty;
  }

  void _track(Route<dynamic> route) {
    final page = _normalize(route.settings.name);
    if (page == null || page.isEmpty) return;

    final extra = _pendingProps;
    _pendingProps = null;

    // 공급자는 복귀 시에도 지금 상태를 읽어 준다. attachNext 로 넘어온 값이
    // 더 구체적이므로(그 이동만의 맥락) 뒤에 둬서 덮어쓰게 한다.
    Map<String, dynamic> fromProvider = const {};
    try {
      fromProvider = _providers[page]?.call() ?? const {};
    } catch (e) {
      debugPrint('[Analytics] $page 프로퍼티 공급 실패: $e');
    }

    Analytics.track(AnalyticsEvent.pageView, {
      AnalyticsProp.locationPage: page,
      AnalyticsProp.prevPage: _currentPage ?? AnalyticsPage.none,
      ...fromProvider,
      ...?extra,
    });
    _currentPage = page;
  }
}

/// `page_view` 추적용 이름이 붙은 [MaterialPageRoute].
///
/// [page] 는 [AnalyticsPage] 의 값을 쓴다. 이름을 빠뜨리면 그 화면의
/// `page_view` 가 조용히 누락되므로, 화면을 여는 곳은 이 함수를 쓴다.
Route<T> analyticsRoute<T>(String page, WidgetBuilder builder) =>
    MaterialPageRoute<T>(builder: builder, settings: RouteSettings(name: page));
