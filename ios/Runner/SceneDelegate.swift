import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// 앱이 꺼진 상태에서 딥링크로 실행될 때 URL 은 여기로 들어온다.
  /// 이때는 Flutter 엔진이 아직 준비되지 않아 채널을 바로 못 쓴다.
  /// Dart 쪽 스플래시 대기 로직에 맡기기 위해 엔진이 붙은 뒤 전달한다.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let url = connectionOptions.urlContexts.first?.url,
          url.scheme == "warding",
          url.host == "widget" || url.host == "match" else { return }

    // 엔진·루트 뷰컨트롤러가 준비될 시간을 준 뒤 채널로 넘긴다.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.sendToFlutter(url)
    }
  }

  /// 딥링크 URL 을 Flutter MethodChannel 로 넘긴다.
  private func sendToFlutter(_ url: URL) {
    guard let controller = window?.rootViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "com.warding.app/widget",
      binaryMessenger: controller.binaryMessenger
    )
    channel.invokeMethod("widgetAction", arguments: url.absoluteString)
  }

  // 위젯 딥링크: 앱이 이미 실행 중일 때
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      let url = context.url
      // widget: 홈 화면 위젯 / match: Live Activity 카드
      // (여기서 안 잡으면 super 가 Flutter 라우팅으로 넘겨
      //  "Failed to handle route information" 이 뜬다.)
      if url.scheme == "warding" && (url.host == "widget" || url.host == "match") {
        sendToFlutter(url)
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
