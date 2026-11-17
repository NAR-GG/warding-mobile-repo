package com.warding.app

import android.app.PendingIntent
import android.content.Context
import android.net.Uri
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

private const val TAG = "WidgetRefresh"

/**
 * 위젯이 앱 없이 스스로 데이터를 다시 받아오게 하는 브로드캐스트 트리거.
 *
 * 세 프로바이더(소·중·대)가 공유한다. 예전에는 대형 위젯만 이걸 쏴서, 소·중
 * 위젯을 쓰는 사람은 앱을 직접 켜기 전까지 캐시된 어제 데이터만 봤다.
 *
 * 디바운스 키는 프로바이더별로 나누지 않고 하나만 쓴다 — 소·중·대를 함께
 * 올려둔 홈 화면에서 시스템 주기 틱이 세 번 오면 같은 갱신을 세 번 쏘게 된다.
 */
object WidgetRefreshTrigger {

    private const val PREFS = "HomeWidgetPreferences"
    private const val KEY_LAST_TRIGGER = "last_refresh_trigger_at"

    /**
     * 10분. 시스템 주기(30분)보다 짧아 정상 틱은 통과시키되,
     * onUpdate() 재진입 체인(수 ms~수 초)은 억제한다.
     *
     * 주의: onUpdate()는 시스템 틱뿐 아니라 HomeWidget.updateWidget() 호출(버튼 탭
     * 처리 결과 등)로도 재진입된다. 디바운스 없이 무조건 발사하면
     * 갱신→onUpdate→갱신의 무한 루프가 생긴다.
     */
    private const val DEBOUNCE_MS = 10 * 60 * 1000L

    /**
     * 백그라운드 재조회를 요청한다.
     *
     * [force] 가 true 면 디바운스를 건너뛴다 — 날짜가 바뀌었거나 저장된 데이터가
     * 오늘 것이 아닌, "지금 안 받으면 틀린 화면을 보여주는" 상황에서만 쓴다.
     */
    fun request(context: Context, force: Boolean = false) {
        // 앱을 한 번도 켜지 않았으면 Dart 콜백 핸들이 저장돼 있지 않다. 그 상태로
        // 브로드캐스트를 쏘면 home_widget 이 엔진을 띄웠다가 콜백을 못 찾고
        // 조용히 빠져나온다 — 위젯만 먼저 설치한 사용자가 여기에 해당한다.
        if (!isBackgroundCallbackRegistered(context)) {
            Log.d(TAG, "background callback not registered yet — skip refresh")
            return
        }
        if (force) {
            // 강제 경로도 시각을 남긴다 — 안 남기면 바로 뒤따라오는 주기 틱이
            // 디바운스를 통과해 같은 갱신을 한 번 더 쏜다.
            markTriggered(context)
        } else if (!shouldTrigger(context)) {
            return
        }
        try {
            HomeWidgetBackgroundIntent
                .getBroadcast(context, Uri.parse("warding://widget/refresh"))
                .send()
        } catch (e: PendingIntent.CanceledException) {
            Log.e(TAG, "refresh background intent failed", e)
        }
    }

    /**
     * `HomeWidget.registerInteractivityCallback` 이 이미 불렸는지.
     *
     * 그 등록은 앱의 `main()` 에서만 일어나므로, 앱을 한 번도 켜지 않았다면
     * false 다. home_widget 이 내부적으로 쓰는 저장소를 그대로 읽는다
     * (패키지의 `HomeWidgetPlugin.getDispatcherHandle` 과 같은 키).
     */
    fun isBackgroundCallbackRegistered(context: Context): Boolean =
        context
            .getSharedPreferences("InternalHomeWidgetPreferences", Context.MODE_PRIVATE)
            .getLong("callbackDispatcherHandle", 0L) != 0L

    private fun shouldTrigger(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lastTriggeredAt = prefs.getLong(KEY_LAST_TRIGGER, 0L)
        val now = System.currentTimeMillis()
        if (now - lastTriggeredAt < DEBOUNCE_MS) return false
        prefs.edit().putLong(KEY_LAST_TRIGGER, now).apply()
        return true
    }

    /**
     * "앱을 열어 주세요" 안내를 켜고 끈다.
     *
     * 앱을 한 번도 켜지 않으면 Dart 백그라운드 콜백이 등록되지 않아 위젯이
     * 스스로 데이터를 받아올 수 없다. 그 상태에서는 빈 화면을 그대로 두지 않고
     * 내용 위에 반투명 막과 "앱 열기" 버튼을 겹쳐 무엇을 해야 하는지 알린다.
     *
     * @param hasData 위젯이 보여줄 데이터를 이미 갖고 있는지.
     */
    fun applyLockedOverlay(
        context: Context,
        views: android.widget.RemoteViews,
        hasData: Boolean,
        compact: Boolean = false,
    ) {
        val locked = !hasData && !isBackgroundCallbackRegistered(context)
        views.setViewVisibility(
            R.id.widget_locked_overlay,
            if (locked) android.view.View.VISIBLE else android.view.View.GONE,
        )
        if (!locked) return

        // 소 위젯처럼 좁은 곳에서는 문구가 잘리므로 짧게 쓴다.
        views.setTextViewText(
            R.id.widget_locked_button,
            if (compact) "앱 열기" else "앱을 열어 일정 불러오기",
        )

        // 버튼과 막 전체 어디를 눌러도 앱이 열리게 한다.
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName) ?: return
        val pending = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_locked_button, pending)
        views.setOnClickPendingIntent(R.id.widget_locked_overlay, pending)
    }

    /** [force] 경로로 쏠 때도 다음 주기 디바운스가 이어지도록 시각을 남긴다. */
    fun markTriggered(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_TRIGGER, System.currentTimeMillis())
            .apply()
    }
}
