import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/analytics.dart';
import 'package:warding/util/analytics_events.dart';

/// `app_open` 진입 경로의 **선점 규칙**을 고정한다.
///
/// 진입 경로를 아는 쪽이 셋이다 — FCM(종료 상태 푸시), 홈 위젯 딥링크,
/// 스플래시(런처). 순서를 호출부들이 서로 맞추게 두면 경로 하나가 늘 때마다
/// 그 약속이 깨지므로, `trackAppOpen` 이 **실행당 첫 호출만** 채택한다.
///
/// 이게 틀어지면 조용히 실패한다 — 스플래시가 `launcher` 로 덮으면 푸시 유입이
/// 통째로 0 이 되는데, 숫자만 보면 "푸시로 들어오는 사람이 없다"로 읽힌다.
/// 그걸 집계 쪽에서 가려낼 방법이 없어 여기서 막는다.
void main() {
  setUp(Analytics.resetAppOpenForTest);

  test('첫 호출이 채택된다', () {
    Analytics.trackAppOpen(AnalyticsEntryPoint.launcher);
    expect(Analytics.appOpenEntryPoint, AnalyticsEntryPoint.launcher);
  });

  test('푸시가 먼저면 스플래시의 launcher 가 덮지 않는다', () {
    // 실제 순서: FcmService.initMessaging (getInitialMessage) 가 runApp 전에
    // 돌고, 스플래시의 consumeNow 는 첫 화면 전환이 끝난 뒤다.
    Analytics.trackAppOpen(AnalyticsEntryPoint.push);
    Analytics.trackAppOpen(AnalyticsEntryPoint.launcher);

    expect(Analytics.appOpenEntryPoint, AnalyticsEntryPoint.push);
  });

  test('위젯이 먼저면 스플래시의 launcher 가 덮지 않는다', () {
    // 위젯 딥링크는 스플래시 전에 도착하면 보류되는데(_pendingWidgetUrl),
    // 경로 기록은 보류보다 먼저 한다 — 그래서 여기서도 위젯이 이긴다.
    Analytics.trackAppOpen(AnalyticsEntryPoint.widget);
    Analytics.trackAppOpen(AnalyticsEntryPoint.launcher);

    expect(Analytics.appOpenEntryPoint, AnalyticsEntryPoint.widget);
  });

  test('앱이 떠 있는 동안 온 딥링크는 진입으로 세지 않는다', () {
    // 런처로 켠 뒤 백그라운드 → 푸시 탭으로 복귀한 경우. 그건 재개지 진입이
    // 아니라서 경로가 바뀌면 안 된다.
    Analytics.trackAppOpen(AnalyticsEntryPoint.launcher);
    Analytics.trackAppOpen(AnalyticsEntryPoint.push);
    Analytics.trackAppOpen(AnalyticsEntryPoint.widget);

    expect(Analytics.appOpenEntryPoint, AnalyticsEntryPoint.launcher);
  });

  test('초기화 전 호출이 예외를 던지지 않는다', () {
    // 테스트·디버그에서는 SDK 가 null 이다. 진입 경로 기록이 앱 부팅을
    // 막으면 안 된다.
    expect(
      () => Analytics.trackAppOpen(AnalyticsEntryPoint.push),
      returnsNormally,
    );
  });

  test('SDK 전 호출은 버리지 않고 보류한다', () {
    // `main()` 이 `_initFirebaseMessaging()`·`HomeWidgetService.init()`·
    // `Analytics.init()` 을 같은 `Future.wait` 로 **병렬** 실행한다. 그래서
    // 푸시·위젯 핸들러가 SDK 초기화보다 먼저 끝날 수 있다. 그때 그냥 쏘면
    // `track` 이 null 인 SDK 에 떨어뜨려 조용히 버리고, 가장 중요한 경로인
    // "푸시로 들어온 콜드 스타트" 가 집계에서 통째로 사라진다.
    Analytics.trackAppOpen(AnalyticsEntryPoint.push);

    expect(Analytics.appOpenEntryPoint, AnalyticsEntryPoint.push);
    expect(
      Analytics.appOpenPending,
      isTrue,
      reason: 'SDK 가 뜨면 init() 이 이 경로를 보내야 한다',
    );
  });

  test('보류 중에도 선점은 그대로 — 뒤에 온 launcher 가 덮지 않는다', () {
    // 전송을 미루는 것이 선점 규칙을 느슨하게 만들면 안 된다.
    Analytics.trackAppOpen(AnalyticsEntryPoint.push);
    Analytics.trackAppOpen(AnalyticsEntryPoint.launcher);

    expect(Analytics.appOpenEntryPoint, AnalyticsEntryPoint.push);
    expect(Analytics.appOpenPending, isTrue);
  });

  test('실행을 되돌리면 보류도 사라진다', () {
    Analytics.trackAppOpen(AnalyticsEntryPoint.push);
    Analytics.resetAppOpenForTest();

    expect(Analytics.appOpenPending, isFalse);
  });

  test('실행이 새로 시작되면 다시 채택한다', () {
    Analytics.trackAppOpen(AnalyticsEntryPoint.push);
    Analytics.resetAppOpenForTest();

    expect(Analytics.appOpenEntryPoint, isNull);
    Analytics.trackAppOpen(AnalyticsEntryPoint.launcher);
    expect(Analytics.appOpenEntryPoint, AnalyticsEntryPoint.launcher);
  });

  test('launcher 는 app_open 전용 값이다', () {
    // 화면 단위 page_view 의 entry_point 와 섞이면 "앱 진입" 과 "화면 진입"
    // 이 같은 축에 들어가 집계가 섞인다. 값이 따로 있는지 고정해 둔다.
    expect(AnalyticsEntryPoint.launcher, 'launcher');
    expect(AnalyticsEvent.appOpen, 'app_open');
  });
}
