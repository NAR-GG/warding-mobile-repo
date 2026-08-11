package com.warding.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.os.Bundle
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

    // 사용자가 위젯 크기를 조절하거나, 런처가 최초 배치 시 디자인보다 큰 칸을 배정하면
    // 패딩을 다시 계산해야 하므로 재렌더링한다.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    companion object {
        private fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        }

        private fun loadWeekStart(context: Context): String =
            getPrefs(context).getString("week_start", "monday") ?: "monday"

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

            // 미니 캘린더 요일 헤더 — 텍스트 순서와 색을 설정에 맞춰 함께 갱신한다.
            val weekStart = loadWeekStart(context)
            val allWdIds = intArrayOf(
                R.id.wd_mon, R.id.wd_tue, R.id.wd_wed, R.id.wd_thu,
                R.id.wd_fri, R.id.wd_sat, R.id.wd_sun
            )
            val orderedLabels = orderedWeekdayLabels(weekStart)
            val sundayCol = if (weekStart == "sunday") 0 else 6
            for (i in allWdIds.indices) {
                views.setTextViewText(allWdIds[i], orderedLabels[i])
                views.setTextColor(allWdIds[i], if (i == sundayCol) sundayColor else weekdayHeaderColor)
            }

            // 왼쪽: 오늘 경기 리스트 채우기
            views.removeAllViews(R.id.matches_container)
            val matches = todayData.matches
            val displayResult = selectDisplayMatches(matches)

            for (displayMatch in displayResult.rows) {
                val m = displayMatch.match
                val row = RemoteViews(context.packageName, R.layout.match_row)
                row.setTextViewText(R.id.match_time, m.time)
                row.setTextViewText(R.id.match_display, m.display)

                when (displayMatch.role) {
                    MatchRole.PAST -> {
                        // 취소선 + 투명도
                        row.setInt(R.id.match_time, "setPaintFlags",
                            Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                        row.setInt(R.id.match_display, "setPaintFlags",
                            Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                        row.setTextColor(R.id.match_time, defaultTextColor)
                        row.setTextColor(R.id.match_display, defaultTextColor)
                        row.setInt(R.id.match_row_root, "setAlpha", 153) // 0.6 * 255
                    }
                    MatchRole.NEXT -> {
                        // 바로 다음 예정(또는 진행중) 경기: 실제 브랜드 그라데이션 텍스트 (다크/라이트 동일)
                        row.setViewVisibility(R.id.match_time, View.GONE)
                        row.setViewVisibility(R.id.match_display, View.GONE)
                        row.setViewVisibility(R.id.match_time_gradient, View.VISIBLE)
                        row.setViewVisibility(R.id.match_display_gradient, View.VISIBLE)
                        row.setImageViewBitmap(R.id.match_time_gradient,
                            renderGradientTextBitmap(context, m.time, 14f, minWidthDp = 42f))
                        row.setImageViewBitmap(R.id.match_display_gradient,
                            renderGradientTextBitmap(context, m.display, 14f))
                    }
                    MatchRole.OTHER -> {
                        // 기본 텍스트 색
                        row.setTextColor(R.id.match_time, defaultTextColor)
                        row.setTextColor(R.id.match_display, defaultTextColor)
                    }
                }

                views.addView(R.id.matches_container, row)
            }

            if (displayResult.overflowCount > 0) {
                val moreRow = RemoteViews(context.packageName, R.layout.match_row)
                moreRow.setTextViewText(R.id.match_time, "+${displayResult.overflowCount}")
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
            val weekStart = loadWeekStart(context)
            val jsonStr = prefs.getString("calendar_data", null)
                ?: return CalendarWidgetData.empty(weekStart)
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
                CalendarWidgetData(year, month, days, weekStart)
            } catch (e: Exception) {
                CalendarWidgetData.empty(weekStart)
            }
        }

        fun loadTodayData(context: Context): TodayWidgetData {
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

private fun isFinishedStatus(status: String): Boolean {
    val s = status.lowercase()
    return s.contains("finish") || s.contains("complet") || s.contains("end")
}

// 브랜드 메인 그라데이션 (Figma: linear-gradient(90.43deg, #E87558 0.76%, #C865C9 51.53%, #791BB8 120.4%)).
// RemoteViews의 TextView는 색상 int 하나만 받아 텍스트에 실제 그라데이션을 칠할 수 없으므로,
// 텍스트를 비트맵에 직접 그려 넣어 RemoteViews.setImageViewBitmap 으로 대체 렌더링한다.
// [minWidthDp] 는 같은 자리의 일반 TextView(minWidth 지정)와 폭을 맞추기 위한 값이다 —
// 그라데이션 비트맵은 텍스트 실측 폭만큼만 그려지므로, minWidth 없이 두면 옆 행의
// minWidth가 적용된 TextView보다 좁아져 뒤 텍스트와의 간격이 행마다 달라 보인다.
fun renderGradientTextBitmap(context: Context, text: String, textSizeSp: Float, minWidthDp: Float = 0f): Bitmap {
    val scaledDensity = context.resources.displayMetrics.scaledDensity
    val density = context.resources.displayMetrics.density
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = textSizeSp * scaledDensity
    }
    val textWidth = paint.measureText(text).coerceAtLeast(1f)
    val fontMetrics = paint.fontMetrics
    val height = (fontMetrics.bottom - fontMetrics.top).coerceAtLeast(1f)

    paint.shader = LinearGradient(
        0f, 0f, textWidth, 0f,
        intArrayOf(Color.parseColor("#E87558"), Color.parseColor("#C865C9"), Color.parseColor("#791BB8")),
        floatArrayOf(0f, 0.43f, 0.83f),
        Shader.TileMode.CLAMP
    )

    val bitmapWidth = maxOf(textWidth, minWidthDp * density).toInt().coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(bitmapWidth, height.toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    canvas.drawText(text, 0f, -fontMetrics.top, paint)
    return bitmap
}

fun selectDisplayMatches(matches: List<TodayMatchInfo>): MatchDisplayResult {
    val sorted = matches.sortedBy { it.time }
    val finished = sorted.filter { isFinishedStatus(it.status) }
    val upcoming = sorted.filter { !isFinishedStatus(it.status) }

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
    val days: Map<Int, List<MatchInfo>>,
    val weekStart: String = "monday"
) {
    companion object {
        fun empty(weekStart: String = "monday"): CalendarWidgetData {
            val cal = Calendar.getInstance()
            return CalendarWidgetData(cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, emptyMap(), weekStart)
        }
    }

    /** 그리드에서 일요일이 위치하는 컬럼(0-based). weekStart="sunday"면 0, 아니면 6. */
    val sundayColumn: Int get() = if (weekStart == "sunday") 0 else 6

    fun firstWeekday(): Int {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        val wd = cal.get(Calendar.DAY_OF_WEEK) // Sun=1 ... Sat=7
        return if (weekStart == "sunday") (wd - 1) else (wd + 5) % 7
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

/** 월~일 순서 요일 라벨을 [weekStart] 기준으로 회전한다. */
fun orderedWeekdayLabels(weekStart: String): List<String> {
    val mondayFirst = listOf("월", "화", "수", "목", "금", "토", "일")
    return if (weekStart == "sunday") listOf(mondayFirst.last()) + mondayFirst.dropLast(1) else mondayFirst
}
