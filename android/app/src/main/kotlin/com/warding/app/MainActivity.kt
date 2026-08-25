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
        // 재진입 경로에서는 이 intent 가 곧 getIntent() 가 된다. onResume 이
        // 같은 것을 다시 처리하지 않도록 여기서 소비했음을 남긴다.
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // 채널이 늦게 준비되는 경로(엔진 재사용 등)를 위해 한 번 더 확인한다.
        flushPendingWidgetUri()
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
        //
        // 앱이 이미 떠 있는 상태에서 위젯 버튼을 누르면 onNewIntent 로 들어오는데,
        // 이때 configureFlutterEngine 은 다시 불리지 않는다. 그래서 보류만 해
        // 두면 아무도 그걸 꺼내 주지 않아 딥링크가 조용히 사라진다(필터 버튼이
        // 반응 없던 원인). 보류해 둔 뒤 다음 프레임에 한 번 더 밀어낸다.
        val ready = channel
        if (ready != null) {
            ready.invokeMethod("widgetAction", uri.toString())
            return
        }

        pendingWidgetUri = uri.toString()
        // 엔진이 이미 살아 있는데 채널만 아직 없을 수 있다(재진입 경로).
        // 메시지 큐 뒤로 한 번 미뤄 채널이 준비됐는지 다시 본다.
        window?.decorView?.post { flushPendingWidgetUri() }
    }

    /** 보류해 둔 딥링크가 있으면 채널을 확보해 흘려보낸다. */
    private fun flushPendingWidgetUri() {
        val uri = pendingWidgetUri ?: return
        val ready = channel ?: ensureChannel() ?: return
        pendingWidgetUri = null
        ready.invokeMethod("widgetAction", uri)
    }

    /**
     * 살아 있는 엔진에서 채널을 만들어 둔다.
     *
     * 이 앱은 [configureFlutterEngine] 이 불리지 않는 경로로 뜬다(암시적 엔진).
     * 그래서 채널이 영영 만들어지지 않고, 보류해 둔 위젯 딥링크를 꺼내 줄
     * 사람이 없어 조용히 사라졌다 — 위젯 필터 버튼이 아무 반응 없던 원인이다.
     *
     * 엔진은 뷰가 붙은 뒤에야 생기므로 onResume 이후에만 잡힌다. 아직 없으면
     * null 을 돌려주고, 다음 기회(onResume·post)에 다시 시도한다.
     */
    private fun ensureChannel(): MethodChannel? {
        // onCreate 시점에는 상위 클래스의 내부 FlutterFragment 가 아직 null 이라
        // 이 게터를 읽는 것만으로 NPE 가 난다(?. 로도 못 막는다). 뷰가 붙은 뒤
        // (onResume 이후)에만 호출해야 한다 — 그래서 방어적으로 감싼다.
        val engine = try {
            flutterEngine
        } catch (e: Exception) {
            null
        } ?: return null
        return MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .also { channel = it }
    }
}
