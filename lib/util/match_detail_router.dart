import 'package:flutter/material.dart';

import '../config/app_globals.dart';
import '../model/schedule_match.dart';
import '../screens/match_detail/match_detail_screen.dart';
import 'analytics.dart';
import 'analytics_events.dart';
import 'analytics_route_observer.dart';

/// 경기 상세로 들어가는 유일한 창구.
///
/// 상세로 향하는 길이 여럿이다 — 경기 목록·경기 일정·마이구독 알림에서 카드를
/// 누르는 길, 그리고 Live Activity 카드·다이나믹 아일랜드·FCM 푸시 같은 딥링크.
/// 이 길들이 각자 `Navigator.push` 를 하면 같은 경기 상세가 겹겹이 쌓인다.
///
/// **스택 상태를 기준으로 판단한다.**
/// - 이미 상세가 떠 있고 같은 경기면: 그 라우트까지 pop 한 뒤 탭·세트만 갱신.
/// - 이미 상세가 떠 있는데 다른 경기면: 그 상세를 걷어내고 새 상세를 push
///   (상세 위에 상세가 겹치지 않게).
/// - 없으면: 평소대로 push.
///
/// 예전에는 이 라우터가 만든 라우트만 맵에 등록해 두고 그걸 기준으로 삼았다.
/// 그래서 목록에서 카드를 눌러 들어간 상세는 맵에 없었고, 그 상태에서 라이브
/// 위젯을 누르면 "떠 있는 상세가 없다"고 오판해 두 장이 겹쳤다. 지금은
/// Navigator 스택을 직접 훑으므로 어느 경로로 열렸든 찾아낸다.
class MatchDetailRouter {
  MatchDetailRouter._();

  /// 열려 있는 상세 라우트 → 그 화면의 State 키.
  ///
  /// 스택을 훑어 상세를 찾을 때 이 표로 라우트를 State 로 옮긴다. 라우트가
  /// 사라지면 스스로 빠진다.
  static final Map<Route<dynamic>, GlobalKey<MatchDetailScreenState>> _open =
      {};

  /// 경기 상세를 연다. 이미 같은 경기가 떠 있으면 그 화면을 재사용한다.
  ///
  /// [tabIndex] 0: 챔피언 픽, 1: 라이브 이벤트, 2: 선수 평점.
  /// [setNumber] 가 있으면 해당 세트를 선택한 상태로 연다.
  /// [match] 는 헤더(스코어·팀명)를 첫 프레임부터 그리기 위한 것으로, 목록에서
  /// 이미 들고 있는 경우에만 넘긴다. 없으면 상세가 matchId 로 직접 받아온다.
  ///
  /// [context] 를 주면 그 Navigator 를, 없으면 전역 [navigatorKey] 를 쓴다.
  /// 딥링크는 화면 밖에서 오므로 context 가 없다.
  ///
  /// 반환 Future 는 상세가 닫힐 때 완료된다 — 목록 화면이 복귀 시점을 알 수
  /// 있도록. 기존 화면을 재사용한 경우엔 곧바로 완료된다(닫힌 게 아니므로).
  /// [entryPoint] 는 `page_view(match_detail)` 에 실린다. 푸시·위젯처럼 앱
  /// 외부에서 들어온 진입은 `prev_page` 만으로 알 수 없어서(앱이 떠 있는
  /// 상태로 푸시를 누르면 prev_page 가 직전 화면이 된다) 따로 받는다.
  ///
  /// [fromPage] 가 있으면 `match_card_click` 을 함께 찍는다 — 목록에서 카드를
  /// 눌러 들어온 경우다. 딥링크·푸시는 카드 클릭이 아니므로 비워 둔다.
  static Future<void> open({
    required String matchId,
    int tabIndex = 0,
    int? setNumber,
    ScheduleMatch? match,
    BuildContext? context,
    String entryPoint = AnalyticsEntryPoint.inApp,
    String? fromPage,
    int? cardPosition,
  }) {
    if (matchId.isEmpty) return Future<void>.value();

    if (fromPage != null) {
      Analytics.track(AnalyticsEvent.matchCardClick, {
        AnalyticsProp.locationPage: fromPage,
        AnalyticsProp.matchId: matchId,
        if (cardPosition case final int p) AnalyticsProp.position: p,
      });
    }
    final nav =
        context != null
            ? Navigator.maybeOf(context)
            : navigatorKey.currentState;
    if (nav == null) return Future<void>.value();

    final existing = _findOpenDetail(nav);

    if (existing != null) {
      final state = existing.value.currentState!;
      if (state.matchId == matchId) {
        // 같은 경기 — 그 화면까지 되돌아가서 탭·세트만 갈아끼운다.
        nav.popUntil((route) => route == existing.key);
        state.applyDeepLink(tabIndex: tabIndex, setNumber: setNumber);
        // 라우트가 바뀌지 않아 AnalyticsRouteObserver 에 콜백이 오지 않는다.
        // 사용자는 상세를 본 것이고, 라이브 경기를 푸시로 연달아 여는 것이
        // 주 동선이라 여기서 직접 찍는다(설계 문서 7번).
        Analytics.track(AnalyticsEvent.pageView, {
          AnalyticsProp.locationPage: AnalyticsPage.matchDetail,
          AnalyticsProp.prevPage:
              AnalyticsRouteObserver.instance.currentPage ?? AnalyticsPage.none,
          AnalyticsProp.matchId: matchId,
          AnalyticsProp.entryPoint: entryPoint,
          AnalyticsProp.locationSection: _sectionOfTab(tabIndex),
        });
        debugPrint(
          '[MatchDetailRouter] 기존 상세 재사용: $matchId '
          '(tab=$tabIndex, set=$setNumber)',
        );
        return Future<void>.value();
      }
      // 다른 경기 — 예전 상세는 걷어내고 새로 연다.
      // 상세가 스택의 첫 라우트면 pop 하지 않는다. 마지막 한 장을 빼면 화면이
      // 아무것도 없는 상태가 되므로, 그 경우엔 새 상세로 교체(replace)한다.
      nav.popUntil((route) => route == existing.key);
      if (nav.canPop()) {
        nav.pop();
      } else {
        // 교체되면 옛 라우트의 completed 가 완료돼 _open 에서 스스로 빠진다.
        _attachPageViewProps(matchId, tabIndex, entryPoint);
        return nav.pushReplacement(
          _buildRoute(
            matchId: matchId,
            tabIndex: tabIndex,
            setNumber: setNumber,
            match: match,
          ),
        );
      }
    }

    debugPrint(
      '[MatchDetailRouter] 상세 push: $matchId (tab=$tabIndex, set=$setNumber)',
    );
    _attachPageViewProps(matchId, tabIndex, entryPoint);
    return nav.push(
      _buildRoute(
        matchId: matchId,
        tabIndex: tabIndex,
        setNumber: setNumber,
        match: match,
      ),
    );
  }

  /// observer 가 쏠 `page_view(match_detail)` 에 이 화면만 아는 맥락을 붙인다.
  static void _attachPageViewProps(
    String matchId,
    int tabIndex,
    String entryPoint,
  ) {
    AnalyticsRouteObserver.instance.attachNext({
      AnalyticsProp.matchId: matchId,
      AnalyticsProp.entryPoint: entryPoint,
      AnalyticsProp.locationSection: _sectionOfTab(tabIndex),
    });
  }

  /// 진입 탭 → `location_section`. 카드 클릭은 0(경기 데이터), 푸시는
  /// 1(라이브 이벤트), 홈 위젯은 `?tab` 에 따라 1 또는 2 로 들어온다.
  static String _sectionOfTab(int tabIndex) => switch (tabIndex) {
    1 => AnalyticsSection.liveEvent,
    2 => AnalyticsSection.playerRating,
    _ => AnalyticsSection.matchData,
  };

  /// 지금 스택에 떠 있는 상세를 찾는다. 없으면 null.
  ///
  /// 라우트가 스택에서 빠졌는데 [_open] 에 남아 있을 수 있어(뒤로가기 직후 등)
  /// **실제로 스택에 있는지**를 [Navigator.popUntil] 순회로 확인한다. 화면이
  /// dispose 됐으면 State 도 없으므로 그것도 함께 거른다.
  static MapEntry<Route<dynamic>, GlobalKey<MatchDetailScreenState>>?
  _findOpenDetail(NavigatorState nav) {
    _open.removeWhere((_, key) => key.currentState == null);
    if (_open.isEmpty) return null;

    // popUntil 의 predicate 는 스택을 위에서부터 훑기만 하고, true 를 돌려주면
    // 아무것도 pop 하지 않는다 — 순회 용도로 쓴다.
    final live = <Route<dynamic>>[];
    nav.popUntil((route) {
      if (_open.containsKey(route)) live.add(route);
      return true;
    });
    if (live.isEmpty) return null;

    // 위에서부터 훑으므로 첫 항목이 가장 최근 상세다.
    final route = live.first;
    return MapEntry(route, _open[route]!);
  }

  /// 상세 라우트를 만들고, 열려 있는 상세로 등록한다.
  /// 라우트가 사라지면(뒤로가기·교체) 등록도 함께 지운다.
  static MaterialPageRoute<void> _buildRoute({
    required String matchId,
    required int tabIndex,
    int? setNumber,
    ScheduleMatch? match,
  }) {
    final key = GlobalKey<MatchDetailScreenState>();
    late final MaterialPageRoute<void> route;
    route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsPage.matchDetail),
      builder:
          (_) => MatchDetailScreen(
            key: key,
            matchId: matchId,
            match: match,
            initialTabIndex: tabIndex,
            initialSet: setNumber,
          ),
    );
    _open[route] = key;
    route.completed.whenComplete(() => _open.remove(route));
    return route;
  }

  /// 테스트 전용 — 등록된 상세를 모두 잊는다. 위젯 테스트는 매번 새 Navigator 를
  /// 만들므로, 앞 테스트가 남긴 라우트가 남아 있으면 다음 테스트가 그것을
  /// 재사용하려 든다.
  @visibleForTesting
  static void resetForTesting() => _open.clear();
}
