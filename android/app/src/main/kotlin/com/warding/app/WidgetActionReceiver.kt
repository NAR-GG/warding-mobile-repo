package com.warding.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 위젯 버튼이 "앱을 열되 특정 화면/모달을 띄워라"를 요청할 때 거치는 리시버.
 *
 * 딥링크(ACTION_VIEW + data)로 앱을 열면 `launchMode=singleTop` 이어도 액티비티가
 * 재생성된다 — Android 는 data 가 다른 인텐트를 다른 요청으로 보기 때문이다.
 * 그러면 `main()` 이 다시 돌아 스플래시부터 화면이 뜨고, 딥링크는 UI 준비 전에
 * 도착해 아무 데도 못 간다. 캘린더 본체를 누를 때는 딥링크가 없어 이 문제가
 * 없었고, 그래서 "캘린더는 바로 열리는데 필터만 앱을 새로 켠다"는 차이가 났다.
 *
 * 그래서 여기서는 요청을 공유 저장소에 남기기만 하고, 앱은 캘린더와 **똑같은**
 * 런처 인텐트로 연다. 앱은 뜨는 즉시·복귀 즉시 이 값을 보고 처리한다
 * (`HomeWidgetService.consumePendingAction`).
 */
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_OPEN_FILTER = "com.warding.app.action.OPEN_FILTER"

        private const val PREFS = "HomeWidgetPreferences"
        private const val KEY_PENDING_ACTION = "pending_widget_action"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_OPEN_FILTER) return

        context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_ACTION, "filter")
            .commit() // 앱이 곧바로 읽으므로 동기 저장한다.

        // 캘린더 본체와 똑같은 런처 인텐트. data 를 얹지 않아 액티비티가
        // 재생성되지 않고 기존 화면이 그대로 앞으로 나온다.
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(launch)
    }
}
