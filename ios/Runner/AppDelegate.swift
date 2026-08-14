import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 위젯·Live Activity 딥링크 채널. 엔진이 뜰 때 한 번 만들어 들고 있는다.
  private var widgetChannel: FlutterMethodChannel?

  /// 채널이 준비되기 전에 도착한 딥링크. 엔진이 뜨면 바로 흘려보낸다.
  private var pendingWidgetURL: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Background App Refresh 등록
    UIApplication.shared.setMinimumBackgroundFetchInterval(
      UIApplication.backgroundFetchIntervalMinimum
    )
    // 앱이 죽어 있을 때 딥링크로 실행되면 URL 이 launchOptions 로 들어온다.
    if let url = launchOptions?[.url] as? URL {
      handleWardingURL(url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 실시간 경기 Live Activity 채널 핸들러. 해제되지 않게 강한 참조로 붙잡는다.
  private var liveActivityPlugin: LiveActivityPlugin?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    liveActivityPlugin = LiveActivityPlugin.register(with: messenger)

    widgetChannel = FlutterMethodChannel(
      name: "com.warding.app/widget",
      binaryMessenger: messenger
    )
    // 엔진이 뜨기 전에 눌린 딥링크를 이제야 전달한다.
    if let pending = pendingWidgetURL {
      pendingWidgetURL = nil
      widgetChannel?.invokeMethod("widgetAction", arguments: pending)
    }
  }

  // 백그라운드 fetch → 위젯 타임라인 갱신 트리거
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    WidgetCenter.shared.reloadAllTimelines()
    completionHandler(.newData)
  }

  // 앱이 포그라운드로 돌아올 때 위젯 갱신
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    WidgetCenter.shared.reloadAllTimelines()
  }

  // 위젯 딥링크 URL을 Flutter MethodChannel로 전달
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if handleWardingURL(url) { return true }
    return super.application(app, open: url, options: options)
  }

  /// warding 딥링크를 Flutter 로 넘긴다. 처리 대상이면 true.
  ///
  /// 예전에는 여기서 `window?.rootViewController as? FlutterViewController` 로
  /// 채널을 만들었는데, FlutterImplicitEngineDelegate 를 쓰는 지금 구조에서는
  /// 앱이 죽어 있다가 딥링크로 켜질 때 이 캐스팅이 실패한다(아직 루트가
  /// FlutterViewController 가 아님). 그러면 URL 이 조용히 버려져서 다이나믹
  /// 아일랜드로 들어와도 상세가 안 열렸다. 이제는 엔진 초기화 때 잡아 둔
  /// 채널을 쓰고, 아직 없으면 보관했다가 엔진이 뜰 때 전달한다.
  @discardableResult
  private func handleWardingURL(_ url: URL) -> Bool {
    // widget: 홈 화면 위젯 / match: Live Activity 카드·다이나믹 아일랜드
    guard url.scheme == "warding",
          url.host == "widget" || url.host == "match" else { return false }

    if let channel = widgetChannel {
      channel.invokeMethod("widgetAction", arguments: url.absoluteString)
    } else {
      pendingWidgetURL = url.absoluteString
    }
    return true
  }
}
