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

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
    if url.scheme == "warding" && url.host == "widget" {
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
