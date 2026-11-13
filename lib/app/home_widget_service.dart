import 'dart:async';

import 'package:home_widget/home_widget.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:warding/core/config/app_globals.dart';
import 'package:warding/features/schedule/data/schedule_widget_writer.dart';
import 'package:warding/app/match_detail_router.dart';
import 'package:warding/features/schedule/presentation/screens/schedule_screen.dart';
import 'package:warding/core/util/analytics.dart';
import 'package:warding/core/util/analytics_events.dart';

/// 홈 화면 위젯을 탭했을 때의 딥링크를 받아 화면을 연다.
///
/// 앱 셸에 있는 이유는 기능 화면을 직접 띄우기 때문이다 — 일정 화면과 경기
/// 상세(라우터 경유) 둘을 안다.
///
/// **위젯에 데이터를 써 넣는 쪽은 [ScheduleWidgetWriter] 다.** 원래 한 파일
/// (1035줄)이었는데 책임이 둘이었다. 데이터 쓰기는 일정 기능이 소유해야 하는
/// 일이라 `features/schedule/data/` 로 내렸다.
class HomeWidgetService {
  HomeWidgetService._();

  /// 앱 시작 시 한 번 호출해 App Group 을 설정한다.
  ///
  /// 위젯 데이터 쓰기·읽기 양쪽이 이 설정을 전제하므로, 쓰기 쪽
  /// ([ScheduleWidgetWriter.init]) 에 두고 여기서 위임한다.
  static Future<void> init() => ScheduleWidgetWriter.init();

  static const _channel = MethodChannel('com.warding.app/widget');

  /// Swift에서 MethodChannel로 전달되는 위젯 액션을 수신한다.
  static void listenWidgetActions() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction') {
        final urlStr = call.arguments as String?;
        if (urlStr != null) _handleWidgetUrl(urlStr);
      }
    });
  }

  /// 스플래시가 첫 화면(로그인/홈) 분기 내비게이션을 시작하기 전에 위젯
  /// 딥링크가 도착하면, 스플래시의 자체 내비게이션과 겹쳐 화면이 두 번
  /// 열리는 것처럼 보인다(FCM 콜드 스타트 딥링크와 동일 문제).
  ///
  /// 한 번 true 가 되면 다시 false 로 돌아가지 않는다 — 앱이 살아 있는 동안
  /// 스플래시는 한 번만 지난다. 그래서 이후의 딥링크(백그라운드 복귀 등)는
  /// 이 플래그를 그대로 통과한다.
  static bool _splashReady = false;
  static String? _pendingWidgetUrl;

  /// 위젯 버튼이 공유 저장소에 남긴 요청을 읽어 처리한다.
  ///
  /// 안드로이드 필터 버튼은 딥링크 대신 이 경로를 쓴다 — 앱을 여는 인텐트를
  /// 캘린더와 똑같이 두어 태스크 재사용 동작을 맞추기 위해서다
  /// (`WidgetActionReceiver` 주석 참고).
  static Future<void> consumePendingAction() async {
    try {
      final action = await HomeWidget.getWidgetData<String>(
        'pending_widget_action',
      );
      if (action == null || action.isEmpty) return;
      await HomeWidget.saveWidgetData<String>('pending_widget_action', '');
      if (action == 'filter') {
        debugPrint('[HomeWidget] 위젯 요청 처리: $action');
        _handleWidgetUrl('warding://widget/filter', skipDuplicateCheck: true);
      }
    } catch (e) {
      debugPrint('[HomeWidget] 위젯 요청 확인 실패: $e');
    }
  }

  /// 스플래시가 첫 화면 분기 내비게이션을 마친 직후 호출한다.
  /// 그 전에 도착해 보류해 둔 위젯 딥링크가 있으면 그 위에 push 한다.
  static void markSplashReady() {
    _splashReady = true;
    _justPassedSplash = true;
    final pending = _pendingWidgetUrl;
    _pendingWidgetUrl = null;
    // 보류분은 아직 화면을 연 적이 없으므로 중복 필터를 건너뛴다. 채널이
    // 늦게 같은 URL 을 또 넘기면 그때 _lastHandledUrl 로 걸러진다.
    if (pending != null) _handleWidgetUrl(pending, skipDuplicateCheck: true);
    // 위젯 버튼이 저장소에 남긴 요청(안드로이드 필터 버튼)도 함께 소비한다.
    unawaited(consumePendingAction());
  }

  /// 마지막으로 처리한 URL과 그 시각. 같은 딥링크가 짧은 간격으로 두 번
  /// 들어오는 걸 걸러낸다.
  ///
  /// 콜드 스타트에서는 같은 URL 이 두 경로로 온다 — 네이티브 채널이 늦게
  /// 전달한 것과, 스플래시가 [markSplashReady] 로 소비한 보류분이다. 둘 다
  /// 통과하면 같은 경기 상세가 두 장 쌓인다(Live Activity 카드 탭 증상).
  ///
  /// 사용자가 카드를 연달아 눌러 같은 화면을 다시 여는 건 막지 않도록
  /// 시간 창을 짧게 둔다.
  static String? _lastHandledUrl;
  static DateTime? _lastHandledAt;
  static const _duplicateWindow = Duration(seconds: 3);

  /// 스플래시를 막 지난 직후인지. 콜드 스타트에서 같은 딥링크가 두 경로로
  /// 도착하는 구간에서만 true 이고, 한 번 딥링크를 처리하면 내려간다.
  /// 중복 필터를 이 구간으로 한정해, 앱이 떠 있는 동안의 재클릭은 통과시킨다.
  static bool _justPassedSplash = false;

  /// 위젯 URL 파싱 후 경기일정 화면으로 이동
  static void _handleWidgetUrl(
    String urlStr, {
    bool skipDuplicateCheck = false,
  }) {
    debugPrint('[HomeWidget] 위젯 URL: $urlStr');
    // 진입 경로를 **보류보다 먼저** 기록한다. 아래에서 `_pendingWidgetUrl` 로
    // 보류되면 실제 내비게이션은 스플래시 뒤로 밀리는데, 그때는 스플래시가
    // 이미 `launcher` 를 쏴 선점해 버린다. 중복은 `trackAppOpen` 이 막는다
    // (백그라운드 복귀로 들어온 두 번째 딥링크는 무시된다 — 진입이 아니다).
    Analytics.trackAppOpen(AnalyticsEntryPoint.widget);

    // 콜드 스타트에서는 스플래시가 첫 화면으로 교체를 마칠 때까지 보류한다.
    //
    // navigator 유무로 판단하면 안 된다 — 스플래시도 MaterialApp 아래에 있어
    // 이 시점에 navigator 는 이미 살아 있다. 그래서 예전 조건은 콜드 스타트에서
    // 보류를 못 하고 스플래시만 있는 스택 위로 상세를 바로 push 했다. 그 뒤
    // 스플래시의 pushReplacement 가 자기 자신을 첫 화면으로 바꾸면서 상세가
    // 첫 화면 아래로 깔려, "상세로 갔다가 일정으로 튕기고 뒤로가면 스플래시"가 됐다.
    //
    // [_splashReady] 는 한 번 true 가 되면 되돌아가지 않으므로, 스플래시를
    // 지난 뒤 도착하는 딥링크(백그라운드 복귀 등)는 그대로 통과한다.
    // [_splashReady] 는 static 이라 프로세스가 살아 있는 동안 유지된다. 그런데
    // 위젯 백그라운드 갱신은 UI 없는 엔진에서 도는데, 그 엔진도 main() 을 거쳐
    // 스플래시를 지나므로 플래그가 true 가 되어 버린다. 그 상태에서 딥링크가
    // 통과하면 Navigator 에 실제 화면이 없어 아무 데도 못 간다(필터가 열리지
    // 않던 원인). 화면이 실제로 붙어 있는지도 함께 본다.
    if (!_splashReady || navigatorKey.currentState?.mounted != true) {
      debugPrint('[HomeWidget] 화면 준비 전 — 딥링크 보류: $urlStr');
      _pendingWidgetUrl = urlStr;
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null) return;

    // Live Activity 카드 / 다이나믹 아일랜드: warding://match/{matchId}?tab=rating&set=N
    //
    // 경기 상세는 URL 문자열 기준 중복 필터를 타지 않는다. 같은 경기라도
    // 누른 위치에 따라 쿼리가 달라서(카드 본문은 tab 없음, 평점 줄은
    // ?tab=rating&set=N) 문자열로는 중복을 못 걸러내고, 반대로 사용자가 3초
    // 안에 카드 → 평점으로 옮겨 누르면 멀쩡한 탭 전환이 씹힌다.
    // 중복 방지는 [MatchDetailRouter] 가 스택 상태로 처리한다.
    if (uri.host == 'match') {
      _openMatchDetail(uri);
      return;
    }

    // 보류분과 채널 전달이 겹쳐 같은 URL 이 두 번 오면 뒤엣것은 버린다.
    //
    // 단, 이 중복은 콜드 스타트에서만 생긴다 — 채널이 늦게 전달한 것과
    // 스플래시가 [markSplashReady] 로 소비한 보류분이 겹치는 경우다. 앱이 이미
    // 떠 있는 상태에서 같은 URL 이 또 오는 건 사용자가 위젯 버튼을 다시 누른
    // 것이므로 막으면 안 된다.
    final at = _lastHandledAt;
    final isColdStartWindow =
        at != null && DateTime.now().difference(at) < _duplicateWindow;
    if (!skipDuplicateCheck &&
        _justPassedSplash &&
        _lastHandledUrl == urlStr &&
        isColdStartWindow) {
      debugPrint('[HomeWidget] 같은 딥링크가 중복 도착해 무시: $urlStr');
      return;
    }
    _lastHandledUrl = urlStr;
    _lastHandledAt = DateTime.now();
    // [_justPassedSplash] 는 여기서 내리지 않는다 — 보류분을 처리한 직후에
    // 채널이 같은 URL 을 또 넘기는 것이 바로 걸러야 할 중복이다. 여기서 내리면
    // 그 두 번째가 새 클릭으로 통과해, 첫 번째가 연 필터 위에 모달 없는 일정
    // 화면이 다시 얹힌다. 플래그는 중복 창이 지나면 [isColdStartWindow] 가
    // false 가 되면서 자연히 무력화된다.

    final action = uri.path.replaceAll('/', '');

    // home 액션: 앱만 열기 (메인 페이지)
    if (action == 'home') return;

    final year = int.tryParse(uri.queryParameters['year'] ?? '');
    final month = int.tryParse(uri.queryParameters['month'] ?? '');

    // prev/next: 위젯에 표시된 월 기준으로 이동할 타겟 월 계산
    DateTime? targetMonth;
    if (year != null && month != null) {
      if (action == 'prev') {
        targetMonth = DateTime(year, month - 1);
      } else if (action == 'next') {
        targetMonth = DateTime(year, month + 1);
      } else {
        targetMonth = DateTime(year, month);
      }
    }

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // 필터는 일정 화면이 이미 보이면 화면을 새로 만들지 않고 열라고 알리기만
    // 한다. 라우트를 갈아끼우면 그 전환 도중에 모달을 열게 되어 모달이 곧바로
    // 함께 걷힌다.
    //
    // 문제는 '보이지 않는' 경우다 — 경기 리스트 등 **다른 하단 탭**에 있으면
    // 일정 화면 자체가 스택에 없어 [openScheduleFilterIfVisible] 이 false 를
    // 돌려주는데, 예전엔 여기서 그냥 return 해 버려서 아무 일도 안 일어났다
    // (요청은 [_filterRequestedBeforeReady] 로 남지만, 그걸 소비할 새
    // ScheduleScreen 이 만들어질 계기 자체가 없다 — 하단 탭은 스택에 없던
    // 화면을 되살리지 않는다). 이때는 아래 prev/next 와 같은 경로로 일정
    // 화면을 만들어야 하고, 그 화면의 initState 가 남겨진 요청을 소비해
    // 필터를 연다.
    if (action == 'filter' && openScheduleFilterIfVisible()) {
      return;
    }

    final route = MaterialPageRoute(
      settings: const RouteSettings(name: AnalyticsPage.schedule),
      builder: (_) => ScheduleScreen(initialMonth: targetMonth),
    );

    // 일정 화면이 스택에 없을 때만 새로 만든다. 첫 화면이면 교체하고,
    // 아니면 그 위에 얹는다.
    if (nav.canPop()) {
      nav.push(route);
    } else {
      nav.pushReplacement(route);
    }
  }

  /// Live Activity 딥링크로 경기 상세를 연다.
  ///
  /// `warding://match/{matchId}?tab=rating&set=N`
  /// - `tab=rating` 이면 선수 평점 탭(인덱스 2)으로, 없으면 기본 탭으로 연다.
  /// - `set` 이 있으면 해당 세트를 선택한 상태로 진입한다.
  static void _openMatchDetail(Uri uri) {
    final matchId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    debugPrint('[LiveActivity] 딥링크 수신: $uri (matchId=$matchId)');
    if (matchId.isEmpty) return;

    final tab = uri.queryParameters['tab'];
    final tabIndex = switch (tab) {
      'rating' => 2,
      'event' => 1,
      _ => 0,
    };
    final set = int.tryParse(uri.queryParameters['set'] ?? '');

    // 같은 경기 상세가 이미 떠 있으면 새로 쌓지 않고 탭·세트만 갈아끼운다.
    MatchDetailRouter.open(
      matchId: matchId,
      tabIndex: tabIndex,
      setNumber: set,
      entryPoint: AnalyticsEntryPoint.widget,
    );
  }

}
