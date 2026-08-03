import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Background App Refresh 등록
    UIApplication.shared.setMinimumBackgroundFetchInterval(
      UIApplication.backgroundFetchIntervalMinimum
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 실시간 경기 Live Activity 채널 핸들러. 해제되지 않게 강한 참조로 붙잡는다.
  private var liveActivityPlugin: LiveActivityPlugin?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    liveActivityPlugin = LiveActivityPlugin.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
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
    // widget: 홈 화면 위젯 / match: Live Activity 카드
    if url.scheme == "warding" && (url.host == "widget" || url.host == "match") {
      if let controller = window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(
          name: "com.warding.app/widget",
          binaryMessenger: controller.binaryMessenger
        )
        channel.invokeMethod("widgetAction", arguments: url.absoluteString)
      }
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
