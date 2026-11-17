package com.warding.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

private const val TAG = "WidgetDateChange"

/**
 * 날짜·시간대가 바뀔 때 위젯을 다시 그리고 데이터를 새로 받아온다.
 *
 * `updatePeriodMillis`(30분) 은 도즈 모드에서 미뤄진다 — 삼성 One UI 처럼 배터리
 * 최적화가 강한 런처에서는 몇 시간씩 안 돌 수 있다. 그래서 자정을 넘겨도
 * 위젯이 어제 데이터를 들고 있는 일이 생긴다. `ACTION_DATE_CHANGED` 는 자정에
 * 시스템이 확실히 쏴 주므로, 이걸 받아 그 자리에서 갱신을 건다.
 *
 * `ACTION_TIME_CHANGED`/`ACTION_TIMEZONE_CHANGED` 도 함께 받는다 — 사용자가
 * 시계를 직접 맞추거나 해외에서 시간대가 바뀌면 "오늘"의 기준이 달라진다.
 */
class WidgetDateChangeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive: ${intent.action}")

        val manager = AppWidgetManager.getInstance(context)

        // 배치된 위젯을 먼저 다시 그린다. 이때 loadTodayData() 가 날짜 불일치를
        // 잡아내 "불러오는 중"으로 바꾸므로, 네트워크가 늦어도 어제 경기가
        // 오늘인 척 남아 있지는 않는다.
        redraw(context, manager, ScheduleWidgetProvider::class.java) { ctx, mgr, id ->
            ScheduleWidgetProvider.updateWidget(ctx, mgr, id)
        }
        redraw(context, manager, ScheduleWidgetSmallProvider::class.java) { ctx, mgr, id ->
            ScheduleWidgetSmallProvider.updateWidget(ctx, mgr, id)
        }
        redraw(context, manager, ScheduleWidgetLargeProvider::class.java) { ctx, mgr, id ->
            ScheduleWidgetLargeProvider.updateWidget(ctx, mgr, id)
        }

        // 날짜가 바뀐 직후의 재조회는 디바운스를 넘긴다 — 30분을 기다리면
        // 그동안 틀린 화면이 그대로 남는다.
        WidgetRefreshTrigger.request(context, force = true)
    }

    private fun redraw(
        context: Context,
        manager: AppWidgetManager,
        provider: Class<*>,
        update: (Context, AppWidgetManager, Int) -> Unit
    ) {
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        for (id in ids) {
            try {
                update(context, manager, id)
            } catch (e: Exception) {
                Log.e(TAG, "redraw failed for ${provider.simpleName} id=$id", e)
            }
        }
    }
}
