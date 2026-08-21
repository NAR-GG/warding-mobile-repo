package com.warding.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import org.json.JSONObject
import java.util.Calendar

private const val TAG = "WidgetMonthShift"

/**
 * 위젯 월 이동(prev/next) 버튼을 받아 **먼저 화면을 바꾸고** 데이터를 요청한다.
 *
 * 실제 조회는 Dart 백그라운드 콜백이 하는데, `home_widget` 이 그것을
 * `JobIntentService` 로 돌려서 안드로이드가 즉시 실행하지 않는다. 실측하면 API 는
 * 230ms 인데 작업이 꺼내지기까지 2~3초가 걸려, 버튼을 눌러도 한참 반응이 없는
 * 것처럼 보였다.
 *
 * 그래서 클릭 즉시 저장된 캘린더의 월만 바꿔 두고 위젯을 다시 그린다. 월 라벨과
 * 격자는 곧바로 새 달로 바뀌고, 경기 칩은 데이터가 도착하면 채워진다.
 */
class WidgetMonthShiftReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_PREV = "com.warding.app.action.MONTH_PREV"
        const val ACTION_NEXT = "com.warding.app.action.MONTH_NEXT"

        private const val PREFS = "HomeWidgetPreferences"
        private const val KEY_CALENDAR = "calendar_data"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val delta = when (intent.action) {
            ACTION_PREV -> -1
            ACTION_NEXT -> 1
            else -> return
        }

        val shifted = shiftStoredMonth(context, delta)
        if (shifted == null) {
            Log.d(TAG, "no stored calendar yet — skip optimistic shift")
            return
        }
        Log.d(TAG, "shifted to $shifted (delta=$delta)")
        redrawLargeWidgets(context)

        // 실제 조회는 기존 경로(Dart 백그라운드 콜백)에 맡긴다. 늦게 도착해도
        // 화면은 이미 새 달을 보여주고 있다.
        try {
            HomeWidgetBackgroundIntent
                .getBroadcast(context, Uri.parse("warding://widget/month?target=$shifted"))
                .send()
        } catch (e: Exception) {
            Log.e(TAG, "month shift request failed", e)
        }
    }

    /**
     * 저장된 캘린더의 `month` 만 [delta] 개월 옮기고 `days` 는 비운다.
     *
     * 경기 칩을 그대로 두면 이전 달 대진이 새 달 격자에 잘못 붙는다. 비워 두면
     * 날짜만 있는 달력이 보이고, 데이터가 도착하면 채워진다.
     *
     * @return 옮긴 뒤의 `yyyy-MM`. 저장값이 없거나 파싱에 실패하면 null.
     */
    private fun shiftStoredMonth(context: Context, delta: Int): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_CALENDAR, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val parts = json.optString("month", "").split("-")
            val year = parts.getOrNull(0)?.toIntOrNull() ?: return null
            val month = parts.getOrNull(1)?.toIntOrNull() ?: return null

            val cal = Calendar.getInstance().apply {
                clear()
                set(year, month - 1, 1)
                add(Calendar.MONTH, delta)
            }
            val shifted = String.format(
                "%04d-%02d",
                cal.get(Calendar.YEAR),
                cal.get(Calendar.MONTH) + 1,
            )

            json.put("month", shifted)
            json.put("days", JSONObject())
            prefs.edit().putString(KEY_CALENDAR, json.toString()).commit()
            shifted
        } catch (e: Exception) {
            Log.e(TAG, "failed to shift stored month", e)
            null
        }
    }

    private fun redrawLargeWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, ScheduleWidgetLargeProvider::class.java)
        )
        for (id in ids) {
            try {
                ScheduleWidgetLargeProvider.updateWidget(context, manager, id)
                manager.notifyAppWidgetViewDataChanged(id, R.id.widget_large_calendar_grid)
            } catch (e: Exception) {
                Log.e(TAG, "redraw failed for id=$id", e)
            }
        }
    }
}
