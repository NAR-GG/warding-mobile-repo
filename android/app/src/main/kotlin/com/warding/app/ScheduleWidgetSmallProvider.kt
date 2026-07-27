package com.warding.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Paint
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

private const val TAG = "ScheduleWidgetSmall"

class ScheduleWidgetSmallProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called, ids=${appWidgetIds.toList()}")
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
                Log.d(TAG, "updateWidget success for id=$appWidgetId")
            } catch (e: Exception) {
                Log.e(TAG, "updateWidget failed for id=$appWidgetId", e)
            }
        }
    }

    companion object {
        private fun isDarkMode(context: Context): Boolean {
            val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            return nightMode == Configuration.UI_MODE_NIGHT_YES
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget_small)
            val todayData = loadTodayData(context)
            val isDark = isDarkMode(context)

            // 배경
            views.setInt(R.id.widget_small_root, "setBackgroundResource",
                if (isDark) R.drawable.widget_background else R.drawable.widget_background_light)

            // 색상 상수
            val defaultTextColor = if (isDark) Color.WHITE else Color.parseColor("#101113")

            // 날짜 헤더
            val cal = Calendar.getInstance()
            val weekdayNames = arrayOf("", "월", "화", "수", "목", "금", "토", "일")
            val sysWd = cal.get(Calendar.DAY_OF_WEEK)
            val wdIdx = if (sysWd == 1) 7 else sysWd - 1
            val dateLabel = String.format(
                "%02d.%02d(%s)",
                cal.get(Calendar.MONTH) + 1,
                cal.get(Calendar.DAY_OF_MONTH),
                weekdayNames[wdIdx]
            )
            views.setTextViewText(R.id.small_date_label, dateLabel)
            views.setTextColor(R.id.small_date_label, defaultTextColor)

            // 경기 리스트
            views.removeAllViews(R.id.small_matches_container)
            val matches = todayData.matches
            val maxShow = 3
            var foundNextScheduled = false

            for (i in 0 until minOf(matches.size, maxShow)) {
                val m = matches[i]
                val row = RemoteViews(context.packageName, R.layout.match_row_small)
                row.setTextViewText(R.id.match_time, m.time)
                row.setTextViewText(R.id.match_display, m.display)

                val isFinished = m.status == "FINISHED" || m.status == "COMPLETED"
                val isLive = m.status == "LIVE" || m.status == "IN_PROGRESS"
                val isNext = !isFinished && !isLive && !foundNextScheduled

                if (isFinished) {
                    row.setInt(R.id.match_time, "setPaintFlags",
                        Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                    row.setInt(R.id.match_display, "setPaintFlags",
                        Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                    row.setTextColor(R.id.match_time, defaultTextColor)
                    row.setTextColor(R.id.match_display, defaultTextColor)
                    row.setInt(R.id.match_row_root, "setAlpha", 153)
                } else if (isLive || isNext) {
                    // LIVE or next scheduled: gradient colors (same in both modes)
                    row.setTextColor(R.id.match_time, Color.parseColor("#E87558"))
                    row.setTextColor(R.id.match_display, Color.parseColor("#C865C9"))
                    if (isNext) foundNextScheduled = true
                } else {
                    // 기본 텍스트 색
                    row.setTextColor(R.id.match_time, defaultTextColor)
                    row.setTextColor(R.id.match_display, defaultTextColor)
                }

                views.addView(R.id.small_matches_container, row)
            }

            if (matches.size > maxShow) {
                val moreRow = RemoteViews(context.packageName, R.layout.match_row_small)
                moreRow.setTextViewText(R.id.match_time, "+${matches.size - maxShow}")
                moreRow.setTextViewText(R.id.match_display, "")
                moreRow.setTextColor(R.id.match_time, defaultTextColor)
                views.addView(R.id.small_matches_container, moreRow)
            }

            if (matches.isEmpty()) {
                val emptyRow = RemoteViews(context.packageName, R.layout.match_row_small)
                emptyRow.setTextViewText(R.id.match_time, "")
                emptyRow.setTextViewText(R.id.match_display, "경기 없음")
                emptyRow.setTextColor(R.id.match_display, Color.parseColor("#A6A7AB"))
                views.addView(R.id.small_matches_container, emptyRow)
            }

            // 앱 열기
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_small_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun loadTodayData(context: Context): TodayWidgetData {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val jsonStr = prefs.getString("today_matches", null)
                ?: return TodayWidgetData.empty()
            return try {
                val json = JSONObject(jsonStr)
                val matchArr = json.optJSONArray("matches") ?: return TodayWidgetData.empty()
                val matches = mutableListOf<TodayMatchInfo>()
                for (i in 0 until matchArr.length()) {
                    val m = matchArr.optJSONObject(i) ?: continue
                    matches.add(TodayMatchInfo(
                        time = m.optString("time", ""),
                        status = m.optString("status", ""),
                        display = m.optString("display", "")
                    ))
                }
                TodayWidgetData(matches)
            } catch (e: Exception) {
                TodayWidgetData.empty()
            }
        }
    }
}
