import 'package:flutter_test/flutter_test.dart';
import 'package:warding/util/analytics.dart';

/// [Analytics.flag] 계열이 **SDK 가 없을 때 fallback 을 주고 던지지 않는지**
/// 검증한다.
///
/// 왜 이것만 테스트하나: 테스트·디버그 빌드에서는 `Analytics.init` 이
/// `kDebugMode` 에 즉시 리턴해 내부 `Mixpanel` 인스턴스가 `null` 이다. 그래서
/// 실제 변형 배정이나 타입 변환 분기는 단위 테스트로 들어갈 수 없다(플랫폼
/// 채널이 필요하다 — 실기기·시뮬레이터에서 `MIXPANEL_DEBUG=true` 로 확인).
///
/// 다만 **이 경로가 앱에서 가장 자주 타는 경로다.** 디버그 개발 내내, 그리고
/// 운영에서도 네트워크 실패·실험 종료 후에는 전부 fallback 으로 떨어진다.
/// 여기서 예외가 새면 플래그를 읽는 화면이 통째로 깨지므로, "실험이 없어도
/// 앱은 멀쩡하다"를 고정해 둔다.
void main() {
  test('초기화 전에는 플래그가 fallback 을 준다', () async {
    expect(Analytics.enabled, isFalse, reason: '테스트에서는 SDK 가 초기화되지 않는다');

    expect(await Analytics.flag('banner_price', 20000), 20000);
    expect(await Analytics.flag('headline', '기본 문구'), '기본 문구');
    expect(await Analytics.flagEnabled('new_onboarding', false), isFalse);
    // fallback 이 true 면 true 를 그대로 돌려줘야 한다(값을 뒤집지 않는다).
    expect(await Analytics.flagEnabled('new_onboarding', true), isTrue);
  });

  test('초기화 전 호출이 예외를 던지지 않는다', () async {
    // 플래그를 읽는 화면이 initState 에서 부르는 경우가 많아, 던지면 화면
    // 전체가 깨진다.
    await expectLater(Analytics.flag('any', 0), completes);
    await expectLater(Analytics.flagEnabled('any', false), completes);
    await expectLater(Analytics.loadFlags(), completes);
    await expectLater(Analytics.tagExperiment('any'), completes);
  });

  test('fallback 타입이 그대로 보존된다', () async {
    // 제네릭이 호출부 타입을 그대로 돌려줘야 한다 — `dynamic` 이 새어 나오면
    // 호출부에서 런타임에 터진다.
    final int price = await Analytics.flag('p', 20000);
    final String copy = await Analytics.flag('c', 'x');
    final double ratio = await Analytics.flag('r', 1.5);
    expect(price, isA<int>());
    expect(copy, isA<String>());
    expect(ratio, isA<double>());
  });
}
