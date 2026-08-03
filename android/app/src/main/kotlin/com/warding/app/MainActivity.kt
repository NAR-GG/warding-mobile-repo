package com.warding.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

// flutter_naver_login 이 Activity 를 FlutterFragmentActivity 로 캐스팅하므로
// FlutterActivity 를 쓰면 플러그인 등록이 실패한다(네이버 로그인 전체 불능).
class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.warding.app/widget"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }

    private fun handleWidgetIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        // widget: 홈 화면 위젯 / match: 실시간 경기 알림
        if (uri.scheme == "warding" && (uri.host == "widget" || uri.host == "match")) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("widgetAction", uri.toString())
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LiveActivityPlugin.register(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }
}
