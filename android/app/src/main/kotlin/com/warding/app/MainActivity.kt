package com.warding.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// flutter_naver_login 이 Activity 를 FlutterFragmentActivity 로 캐스팅하므로
// FlutterActivity 를 쓰면 플러그인 등록이 실패한다(네이버 로그인 전체 불능).
class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.warding.app/widget"

    /** 엔진이 붙기 전에 들어온 위젯 딥링크. 붙는 즉시 흘려보낸다. */
    private var pendingWidgetUri: String? = null

    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }

    // 엔진이 준비된 뒤에 불린다. 여기서 채널을 만들어 두고, onCreate 때
    // 처리하지 못하고 남겨 둔 딥링크가 있으면 지금 보낸다.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        pendingWidgetUri?.let { uri ->
            pendingWidgetUri = null
            channel?.invokeMethod("widgetAction", uri)
        }
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
    }

    private fun handleWidgetIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        // widget: 홈 화면 위젯 딥링크
        if (uri.scheme != "warding" || uri.host != "widget") return

        // 콜드 스타트에서는 onCreate 시점에 아직 엔진이 없다. 이때
        // `flutterEngine` 을 읽으면 상위 클래스가 내부 FlutterFragment 를
        // 참조하는데 그게 아직 null 이라 NPE 로 죽는다(?. 는 게터 호출 자체를
        // 막아 주지 못한다). 위젯을 눌러 앱을 처음 켜는 경로가 정확히 이것이다.
        //
        // 그래서 여기서는 엔진을 건드리지 않고, 채널이 준비돼 있으면 바로
        // 보내고 아니면 남겨 뒀다가 configureFlutterEngine 에서 보낸다.
        val ready = channel
        if (ready != null) {
            ready.invokeMethod("widgetAction", uri.toString())
        } else {
            pendingWidgetUri = uri.toString()
        }
    }
}
