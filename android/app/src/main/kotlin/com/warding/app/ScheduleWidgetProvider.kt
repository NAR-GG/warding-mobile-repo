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
// 경기 행 최대 노출 수. 위젯 높이가 1칸(40dp~)이라 이 이상은 잘린다.
// iOS 위젯은 세로 여유가 있어 3개(WardingScheduleWidget.swift 의 maxShow)를 쓴다.
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
        // 캐시 재렌더링만으로는 데이터가 늙는다 — 실제 네트워크 재조회도 건다.
        // (예전에는 대형 위젯만 이걸 해서, 중 위젯 사용자는 앱을 켜기 전까지
        //  어제 데이터를 봤다.)
        WidgetRefreshTrigger.request(context)
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

        /**
         * 런처가 이 위젯에 배정한 높이(dp). 사용자가 리사이즈하면 함께 바뀐다.
         * 옵션을 못 읽으면 0 을 돌려 호출부가 기본값을 쓰게 한다.
         */
        fun grantedHeightDp(context: Context, appWidgetId: Int): Int {
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return 0
            val options = AppWidgetManager.getInstance(context)
                .getAppWidgetOptions(appWidgetId) ?: return 0
            // 세로 모드에서는 MAX_HEIGHT 가 실제 배정 높이에 가깝다.
            return options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
                .takeIf { it > 0 }
                ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
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
            val displayResult = selectDisplayMatches(
                matches,
                slotsForHeight(grantedHeightDp(context, appWidgetId)),
            )

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
                        row.setTextColor(R.id.match_time, fadedTextColor(defaultTextColor))
                        row.setTextColor(R.id.match_display, fadedTextColor(defaultTextColor))
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
                // 날짜가 어긋난 데이터는 "경기 없음"이 아니다 — 아래에서 재조회를 건다.
                emptyRow.setTextViewText(
                    R.id.match_display,
                    emptyMessage(context, todayData.isStale)
                )
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

            // 앱을 아직 안 켜서 데이터를 받아올 수 없으면 안내를 겹친다.
            // 중 위젯도 기본 높이가 1칸이라 긴 문구는 버튼이 눌린다.
            WidgetRefreshTrigger.applyLockedOverlay(
                context,
                views,
                hasData = !todayData.isStale,
                compact = grantedHeightDp(context, appWidgetId) < 100,
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_calendar_grid)

            // 저장된 게 오늘 것이 아니면(자정 넘김·최초 배치) 디바운스를 무시하고
            // 바로 다시 받아온다. 이 경우는 기다려 봐야 틀린 화면만 유지된다.
            if (todayData.isStale) {
                WidgetRefreshTrigger.request(context, force = true)
            }
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

        /** 저장된 오늘 경기 데이터를 읽는다. 날짜 판정은 [parseTodayData] 참고. */
        fun loadTodayData(context: Context): TodayWidgetData =
            parseTodayData(getPrefs(context).getString("today_matches", null), todayKey())
    }
}

data class MatchInfo(val blue: String, val red: String, val display: String)

data class TodayMatchInfo(val time: String, val status: String, val display: String)

/**
 * 위젯에 그릴 오늘 경기 데이터.
 *
 * [isStale] 은 "저장된 게 오늘 것이 아니거나 아직 없다"는 뜻으로, 경기가 정말
 * 없는 날([matches] 가 비었고 [isStale] 이 false)과 구분해야 한다. 전자는
 * "경기 없음"이 아니라 "불러오는 중"으로 보여주고 재조회를 걸어야 한다.
 */
data class TodayWidgetData(
    val matches: List<TodayMatchInfo>,
    val isStale: Boolean = false
) {
    companion object {
        fun empty() = TodayWidgetData(emptyList())

        fun stale() = TodayWidgetData(emptyList(), isStale = true)
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
//
// [textSizeDp] 는 dp 다. 위젯 레이아웃의 텍스트를 모두 dp 로 고정했기 때문에
// (시스템 글꼴 배율을 따라가면 dp 로 고정된 행 높이 안에서 글자가 잘린다)
// 여기서도 scaledDensity 가 아니라 density 를 곱해야 같은 크기로 그려진다.
fun renderGradientTextBitmap(context: Context, text: String, textSizeDp: Float, minWidthDp: Float = 0f): Bitmap {
    val density = context.resources.displayMetrics.density
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = textSizeDp * density
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
    // 이미 기기 density 기준 픽셀로 그렸으므로, 비트맵에도 같은 density 를 박아
    // ImageView 가 다시 스케일하지 않게 한다. 기본값(DENSITY_DEFAULT=160)으로
    // 두면 고밀도 기기에서 ImageView 가 제 나름대로 축소·확대해, 같은 14sp 인데도
    // 옆 TextView 보다 글자가 작아 보인다.
    bitmap.density = context.resources.displayMetrics.densityDpi
    val canvas = Canvas(bitmap)
    canvas.drawText(text, 0f, -fontMetrics.top, paint)
    return bitmap
}

/**
 * 오늘 날짜를 앱이 저장하는 것과 같은 `yyyy-MM-dd` 형태로 만든다
 * (`HomeWidgetService._saveTodayDetailed` 등의 `date` 필드와 맞춰야 한다).
 */
fun todayKey(calendar: Calendar = Calendar.getInstance()): String = String.format(
    "%04d-%02d-%02d",
    calendar.get(Calendar.YEAR),
    calendar.get(Calendar.MONTH) + 1,
    calendar.get(Calendar.DAY_OF_MONTH)
)

/**
 * 저장된 오늘 경기 JSON 을 파싱한다.
 *
 * JSON 의 `date` 가 [todayKey] 와 다르면 [TodayWidgetData.stale] 을 돌려준다.
 * 예전에는 `date` 를 읽지도 않고 `matches` 만 꺼내 썼는데, 그래서 자정을 넘기면
 * 헤더 날짜만 오늘로 바뀌고 경기 목록은 어제 것이 그대로 남았다 (어제 경기가 다
 * 끝났으면 취소선 한 줄, 어제가 경기 없는 날이었으면 "경기 없음"). 날짜가 어긋난
 * 데이터는 "없음"이 아니라 "아직 모름"이므로 빈 목록과 구분해서 다루고,
 * 호출부가 재조회를 걸도록 한다.
 */
fun parseTodayData(jsonStr: String?, todayKey: String): TodayWidgetData {
    if (jsonStr == null) return TodayWidgetData.stale()
    return try {
        val json = JSONObject(jsonStr)
        if (json.optString("date", "") != todayKey) return TodayWidgetData.stale()
        val matchArr = json.optJSONArray("matches") ?: return TodayWidgetData.stale()
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
        TodayWidgetData.stale()
    }
}

/**
 * 지난 경기 행에 쓰는 흐린 텍스트 색 (원래 의도: 행 전체 알파 0.6).
 *
 * 예전에는 `setInt(rowRoot, "setAlpha", 153)` 으로 행 전체를 흐리게 했는데,
 * `View.setAlpha` 는 `float` 을 받아서 `setInt` 리플렉션이 메서드를 못 찾고
 * `RemoteViews$ActionException` 을 던졌다. 그러면 행 하나가 아니라 **위젯
 * 전체 인플레이트가 실패**해 런처에 "Can't load widget" 이 뜬다.
 *
 * `RemoteViews.setFloat` 은 API 31+ 라 minSdk 24 에서는 못 쓴다. 어차피 이
 * 행에서 흐려질 대상은 텍스트 둘뿐이라 색상 알파로 같은 결과를 낸다.
 */
fun fadedTextColor(baseColor: Int): Int =
    (baseColor and 0x00FFFFFF) or (153 shl 24) // 0.6 * 255

/**
 * 보여줄 경기가 없을 때의 문구.
 *
 * 세 경우를 구분한다.
 * - 오늘 데이터가 있고 경기가 없는 날 → "경기 없음"
 * - 데이터가 낡았고 스스로 다시 받아올 수 있음 → "불러오는 중"
 * - 앱을 한 번도 켜지 않아 재조회 경로 자체가 없음 → 앱을 열어 달라고 안내
 *
 * 마지막 경우를 "불러오는 중"으로 두면 기다리면 채워질 것처럼 보이는데, 실제로는
 * 앱을 한 번 열기 전까지 영영 그대로다 (Dart 백그라운드 콜백이 등록되지 않아서).
 * 위젯을 앱보다 먼저 설치한 사용자가 여기에 해당한다.
 */
fun emptyMessage(context: Context, isStale: Boolean): String = when {
    !isStale -> "경기 없음"
    WidgetRefreshTrigger.isBackgroundCallbackRegistered(context) -> "불러오는 중"
    else -> "앱을 열어 주세요"
}

/**
 * 배정된 높이에 몇 개의 경기 행이 들어가는지 계산한다.
 *
 * 위젯 최소 크기는 1칸이지만 사용자가 리사이즈로 늘릴 수 있다. 고정 개수만
 * 보여주면 늘려도 아래가 빈 채로 남으므로, 실제 배정 높이에서 헤더·패딩을 뺀
 * 만큼을 행 높이로 나눠 slot 수를 구한다 (대형 위젯의 maxChipsPerDay 와 같은 방식).
 *
 * [grantedHeightDp] 를 못 구하면(옵션 미제공) [MAX_REAL_SLOTS] 로 대체한다.
 */
fun slotsForHeight(grantedHeightDp: Int): Int {
    if (grantedHeightDp <= 0) return MAX_REAL_SLOTS
    // widget_root 상하 패딩 24dp + 날짜 헤더 22dp(16sp + paddingBottom 8dp).
    val chromeDp = 24 + 22
    // match_row: 높이 20dp + layout_marginBottom 3dp.
    val rowDp = 23
    val available = grantedHeightDp - chromeDp
    // "+N" 줄이 들어갈 자리를 남기지 않는다 — 넘칠 때만 마지막 행을 대체한다.
    return (available / rowDp).coerceIn(1, MAX_ROW_CAP)
}

/** 아무리 늘려도 이 이상은 안 보여준다 (캘린더 쪽 높이와 균형). */
private const val MAX_ROW_CAP = 6

fun selectDisplayMatches(
    matches: List<TodayMatchInfo>,
    maxSlots: Int = MAX_REAL_SLOTS,
): MatchDisplayResult {
    val sorted = matches.sortedBy { it.time }
    val finished = sorted.filter { isFinishedStatus(it.status) }
    val upcoming = sorted.filter { !isFinishedStatus(it.status) }

    // 지난 경기는 가장 최근에 끝난 1개만 노출한다.
    val pastShown = finished.lastOrNull()
    val remainingSlots = maxSlots - (if (pastShown != null) 1 else 0)
    val upcomingShown = upcoming.take(remainingSlots.coerceAtLeast(0))

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
