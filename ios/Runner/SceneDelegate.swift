import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // 위젯 딥링크: 앱이 이미 실행 중일 때
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      let url = context.url
      if url.scheme == "warding" && url.host == "widget" {
        if let controller = window?.rootViewController as? FlutterViewController {
          let channel = FlutterMethodChannel(
            name: "com.warding.app/widget",
            binaryMessenger: controller.binaryMessenger
          )
          channel.invokeMethod("widgetAction", arguments: url.absoluteString)
        }
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
