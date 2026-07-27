package com.warding.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Paint
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

private const val TAG = "ScheduleWidget"
private const val MAX_REAL_SLOTS = 2

class ScheduleWidgetProvider : AppWidgetProvider() {

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
        private fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        }

        fun isDarkMode(context: Context): Boolean {
            val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            return nightMode == Configuration.UI_MODE_NIGHT_YES
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget)
            val todayData = loadTodayData(context)
            val isDark = isDarkMode(context)

            // 배경
            views.setInt(R.id.widget_root, "setBackgroundResource",
                if (isDark) R.drawable.widget_background else R.drawable.widget_background_light)

            // 색상 상수
            val defaultTextColor = if (isDark) Color.WHITE else Color.parseColor("#101113")
            val sundayColor = if (isDark) Color.parseColor("#9672AC") else Color.parseColor("#6D2E92")
            val weekdayHeaderColor = if (isDark) Color.WHITE else Color.BLACK

            // 왼쪽: 오늘 날짜 헤더
            val cal = Calendar.getInstance()
            val weekdayNames = arrayOf("", "월", "화", "수", "목", "금", "토", "일")
            val sysWd = cal.get(Calendar.DAY_OF_WEEK) // Sun=1
            val wdIdx = if (sysWd == 1) 7 else sysWd - 1
            val dateLabel = String.format(
                "%02d.%02d(%s)",
                cal.get(Calendar.MONTH) + 1,
                cal.get(Calendar.DAY_OF_MONTH),
                weekdayNames[wdIdx]
            )
            views.setTextViewText(R.id.today_date_label, dateLabel)
            views.setTextColor(R.id.today_date_label, defaultTextColor)

            // 미니 캘린더 요일 헤더 색상
            val wdIds = intArrayOf(R.id.wd_mon, R.id.wd_tue, R.id.wd_wed, R.id.wd_thu, R.id.wd_fri, R.id.wd_sat)
            for (id in wdIds) {
                views.setTextColor(id, weekdayHeaderColor)
            }
            views.setTextColor(R.id.wd_sun, sundayColor)

            // 왼쪽: 오늘 경기 리스트 채우기
            views.removeAllViews(R.id.matches_container)
            val matches = todayData.matches
            val maxShow = 3
            var foundNextScheduled = false

            for (i in 0 until minOf(matches.size, maxShow)) {
                val m = matches[i]
                val row = RemoteViews(context.packageName, R.layout.match_row)
                row.setTextViewText(R.id.match_time, m.time)
                row.setTextViewText(R.id.match_display, m.display)

                val isFinished = m.status == "FINISHED" || m.status == "COMPLETED"
                val isLive = m.status == "LIVE" || m.status == "IN_PROGRESS"
                val isNext = !isFinished && !isLive && !foundNextScheduled

                if (isFinished) {
                    // 취소선 + 투명도
                    row.setInt(R.id.match_time, "setPaintFlags",
                        Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                    row.setInt(R.id.match_display, "setPaintFlags",
                        Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                    row.setTextColor(R.id.match_time, defaultTextColor)
                    row.setTextColor(R.id.match_display, defaultTextColor)
                    row.setInt(R.id.match_row_root, "setAlpha", 153) // 0.6 * 255
                } else if (isLive || isNext) {
                    // LIVE or 다음 예정 경기: narBg 느낌의 그라데이션 색 (same in both modes)
                    row.setTextColor(R.id.match_time, Color.parseColor("#E87558"))
                    row.setTextColor(R.id.match_display, Color.parseColor("#C865C9"))
                    if (isNext) foundNextScheduled = true
                } else {
                    // 기본 텍스트 색
                    row.setTextColor(R.id.match_time, defaultTextColor)
                    row.setTextColor(R.id.match_display, defaultTextColor)
                }

                views.addView(R.id.matches_container, row)
            }

            if (matches.size > maxShow) {
                val moreRow = RemoteViews(context.packageName, R.layout.match_row)
                moreRow.setTextViewText(R.id.match_time, "+${matches.size - maxShow}")
                moreRow.setTextViewText(R.id.match_display, "")
                moreRow.setTextColor(R.id.match_time, defaultTextColor)
                views.addView(R.id.matches_container, moreRow)
            }

            if (matches.isEmpty()) {
                val emptyRow = RemoteViews(context.packageName, R.layout.match_row)
                emptyRow.setTextViewText(R.id.match_time, "")
                emptyRow.setTextViewText(R.id.match_display, "경기 없음")
                emptyRow.setTextColor(R.id.match_display, Color.parseColor("#A6A7AB"))
                views.addView(R.id.matches_container, emptyRow)
            }

            // 오른쪽: 미니 캘린더 (ListView)
            val intent = android.content.Intent(context, ScheduleWidgetService::class.java)
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            intent.data = android.net.Uri.parse(intent.toUri(android.content.Intent.URI_INTENT_SCHEME))
            views.setRemoteAdapter(R.id.widget_calendar_grid, intent)

            // 앱 열기 인텐트
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_calendar_grid)
        }

        fun loadCalendarData(context: Context): CalendarWidgetData {
            val prefs = getPrefs(context)
            val jsonStr = prefs.getString("calendar_data", null)
                ?: return CalendarWidgetData.empty()
            return try {
                val json = JSONObject(jsonStr)
                val monthStr = json.optString("month", "")
                val parts = monthStr.split("-")
                val year = parts.getOrNull(0)?.toIntOrNull()
                    ?: Calendar.getInstance().get(Calendar.YEAR)
                val month = parts.getOrNull(1)?.toIntOrNull()
                    ?: (Calendar.getInstance().get(Calendar.MONTH) + 1)
                val daysObj = json.optJSONObject("days") ?: JSONObject()
                val days = mutableMapOf<Int, List<MatchInfo>>()
                val keys = daysObj.keys()
                while (keys.hasNext()) {
                    val dayStr = keys.next()
                    val dayNum = dayStr.toIntOrNull() ?: continue
                    val matchArr = daysObj.optJSONArray(dayStr) ?: continue
                    val matches = mutableListOf<MatchInfo>()
                    for (i in 0 until matchArr.length()) {
                        val m = matchArr.optJSONObject(i) ?: continue
                        matches.add(MatchInfo(
                            blue = m.optString("blue", ""),
                            red = m.optString("red", ""),
                            display = m.optString("display", "")
                        ))
                    }
                    days[dayNum] = matches
                }
                CalendarWidgetData(year, month, days)
            } catch (e: Exception) {
                CalendarWidgetData.empty()
            }
        }

        private fun loadTodayData(context: Context): TodayWidgetData {
            val prefs = getPrefs(context)
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

data class MatchInfo(val blue: String, val red: String, val display: String)

data class TodayMatchInfo(val time: String, val status: String, val display: String)

data class TodayWidgetData(val matches: List<TodayMatchInfo>) {
    companion object {
        fun empty() = TodayWidgetData(emptyList())
    }
}

enum class MatchRole { PAST, NEXT, OTHER }

data class DisplayMatch(val match: TodayMatchInfo, val role: MatchRole)

data class MatchDisplayResult(val rows: List<DisplayMatch>, val overflowCount: Int)

fun selectDisplayMatches(matches: List<TodayMatchInfo>): MatchDisplayResult {
    val sorted = matches.sortedBy { it.time }
    val finished = sorted.filter { it.status == "FINISHED" || it.status == "COMPLETED" }
    val upcoming = sorted.filter { it.status != "FINISHED" && it.status != "COMPLETED" }

    // 지난 경기는 가장 최근에 끝난 1개만 노출한다.
    val pastShown = finished.lastOrNull()
    val remainingSlots = MAX_REAL_SLOTS - (if (pastShown != null) 1 else 0)
    val upcomingShown = upcoming.take(remainingSlots)

    val rows = mutableListOf<DisplayMatch>()
    if (pastShown != null) {
        rows.add(DisplayMatch(pastShown, MatchRole.PAST))
    }
    upcomingShown.forEachIndexed { index, m ->
        rows.add(DisplayMatch(m, if (index == 0) MatchRole.NEXT else MatchRole.OTHER))
    }

    val overflow = sorted.size - rows.size
    return MatchDisplayResult(rows, overflow)
}

data class CalendarWidgetData(
    val year: Int,
    val month: Int,
    val days: Map<Int, List<MatchInfo>>
) {
    companion object {
        fun empty(): CalendarWidgetData {
            val cal = Calendar.getInstance()
            return CalendarWidgetData(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, emptyMap())
        }
    }

    fun firstWeekday(): Int {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        val wd = cal.get(Calendar.DAY_OF_WEEK)
        return (wd + 5) % 7
    }

    fun daysInMonth(): Int {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        return cal.getActualMaximum(Calendar.DAY_OF_MONTH)
    }

    fun prevMonthDays(): Int {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        cal.add(Calendar.MONTH, -1)
        return cal.getActualMaximum(Calendar.DAY_OF_MONTH)
    }

    fun weekCount(): Int = ((firstWeekday() + daysInMonth() - 1) / 7) + 1
}
