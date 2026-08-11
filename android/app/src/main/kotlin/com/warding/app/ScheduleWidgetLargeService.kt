package com.warding.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.text.Html
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.Calendar

private const val TAG = "ScheduleWidgetLargeSvc"

class ScheduleWidgetLargeService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        Log.d(TAG, "onGetViewFactory called")
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID
        )
        return LargeCalendarRemoteViewsFactory(applicationContext, appWidgetId)
    }
}

class LargeCalendarRemoteViewsFactory(
    private val context: Context,
    private val appWidgetId: Int
) : RemoteViewsService.RemoteViewsFactory {

    private var data = CalendarWidgetData.empty()
    private val isDark: Boolean = run {
        val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        nightMode == Configuration.UI_MODE_NIGHT_YES
    }

    // 헤더(36dp) + 요일 행(19dp) + 구분선(1dp) + 상하 패딩(4dp+4dp) — schedule_widget_large.xml 기준.
    private val chromeHeightDp = 36 + 19 + 1 + 4 + 4

    override fun onCreate() {
        Log.d(TAG, "Factory onCreate")
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged")
        data = ScheduleWidgetProvider.loadCalendarData(context)
        Log.d(TAG, "loaded data: year=${data.year} month=${data.month} weekCount=${data.weekCount()} days=${data.days.size}")
    }

    override fun onDestroy() {}

    override fun getCount(): Int = data.weekCount()

    /**
     * 위젯의 현재 세로 크기(dp)에서 헤더 영역을 뺀 뒤 주(week) 수로 나눠, 캘린더 그리드가
     * 남는 공백 없이 위젯 전체 높이를 채우도록 한 행이 가져야 할 높이(px)를 계산한다.
     * 옵션을 못 읽거나 계산값이 0 이하면 0을 반환해 레이아웃 XML의 기본(minHeight=54dp)을 그대로 쓴다.
     */
    private fun rowHeightPx(): Int {
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return 0
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId)
        val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        if (minHeightDp <= 0) return 0
        val gridHeightDp = (minHeightDp - chromeHeightDp).coerceAtLeast(0)
        if (gridHeightDp <= 0) return 0
        val weeks = data.weekCount().coerceAtLeast(1)
        val rowHeightDp = gridHeightDp / weeks
        val density = context.resources.displayMetrics.density
        return (rowHeightDp * density).toInt()
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_large_row)
        val rowHeight = rowHeightPx()
        if (rowHeight > 0) {
            views.setInt(R.id.large_row_root, "setMinimumHeight", rowHeight)
        }
        val week = position
        val firstWd = data.firstWeekday()
        val dim = data.daysInMonth()
        val prevDim = data.prevMonthDays()
        val now = Calendar.getInstance()
        val todayDay = if (now.get(Calendar.YEAR) == data.year &&
            now.get(Calendar.MONTH) + 1 == data.month
        ) now.get(Calendar.DAY_OF_MONTH) else -1

        val maxChipsPerDay = if (data.weekCount() >= 6) 1 else 2

        // 색상 상수
        val defaultDayColor = if (isDark) Color.WHITE else Color.BLACK
        val sundayColor = if (isDark) Color.parseColor("#FF9672AC") else Color.parseColor("#FF6D2E92")
        val nonCurrentMonthColor = if (isDark) Color.parseColor("#80FFFFFF") else Color.parseColor("#80000000")
        val chipTeamColor = if (isDark) "#FFFFFF" else "#101113"
        val moreTextColor = if (isDark) Color.WHITE else Color.BLACK

        val dayNumIds = intArrayOf(
            R.id.large_day0_num, R.id.large_day1_num, R.id.large_day2_num,
            R.id.large_day3_num, R.id.large_day4_num, R.id.large_day5_num, R.id.large_day6_num
        )
        val dayChipIds = intArrayOf(
            R.id.large_day0_chip, R.id.large_day1_chip, R.id.large_day2_chip,
            R.id.large_day3_chip, R.id.large_day4_chip, R.id.large_day5_chip, R.id.large_day6_chip
        )
        val dayChip2Ids = intArrayOf(
            R.id.large_day0_chip2, R.id.large_day1_chip2, R.id.large_day2_chip2,
            R.id.large_day3_chip2, R.id.large_day4_chip2, R.id.large_day5_chip2, R.id.large_day6_chip2
        )
        val dayMoreIds = intArrayOf(
            R.id.large_day0_more, R.id.large_day1_more, R.id.large_day2_more,
            R.id.large_day3_more, R.id.large_day4_more, R.id.large_day5_more, R.id.large_day6_more
        )
        val dayCellIds = intArrayOf(
            R.id.large_day0_cell, R.id.large_day1_cell, R.id.large_day2_cell,
            R.id.large_day3_cell, R.id.large_day4_cell, R.id.large_day5_cell, R.id.large_day6_cell
        )
        val dayBorderIds = intArrayOf(
            R.id.large_day0_border, R.id.large_day1_border, R.id.large_day2_border,
            R.id.large_day3_border, R.id.large_day4_border, R.id.large_day5_border
        )

        for (dow in 0..6) {
            val offset = week * 7 + dow - firstWd
            val dayNum = offset + 1

            val displayDay: Int
            val isCurrentMonth: Boolean

            when {
                dayNum < 1 -> {
                    displayDay = prevDim + dayNum
                    isCurrentMonth = false
                }
                dayNum > dim -> {
                    displayDay = dayNum - dim
                    isCurrentMonth = false
                }
                else -> {
                    displayDay = dayNum
                    isCurrentMonth = true
                }
            }

            // 날짜 숫자
            views.setTextViewText(dayNumIds[dow], "$displayDay")

            // 오늘 여부
            val isToday = isCurrentMonth && dayNum == todayDay
            val isSunday = dow == data.sundayColumn

            // 날짜 숫자 색상
            val textColor = when {
                !isCurrentMonth -> nonCurrentMonthColor
                isToday -> Color.parseColor("#FFFF6B6B") // same in both modes
                isSunday -> sundayColor
                else -> defaultDayColor
            }
            views.setTextColor(dayNumIds[dow], textColor)

            // 오늘 셀 배경
            if (isToday) {
                views.setInt(dayCellIds[dow], "setBackgroundResource",
                    if (isDark) R.drawable.large_today_bg else R.drawable.large_today_bg_light)
            } else {
                views.setInt(dayCellIds[dow], "setBackgroundColor", Color.TRANSPARENT)
            }

            // 셀 구분선 (day6 has no border view) - keep #80A6A7AB same
            if (dow < 6) {
                views.setViewVisibility(dayBorderIds[dow], View.VISIBLE)
            }

            // 경기 칩 표시
            val matches = if (isCurrentMonth) data.days[dayNum] else null
            if (matches != null && matches.isNotEmpty()) {
                // 칩 배경
                val chipBgRes = if (isDark) R.drawable.large_chip_bg else R.drawable.large_chip_bg_light

                // 첫 번째 칩
                val firstMatch = matches[0]
                val chipHtml1 = "<font color='$chipTeamColor'>${firstMatch.blue}</font><font color='#F03E3E'>VS</font><font color='$chipTeamColor'>${firstMatch.red}</font>"
                views.setTextViewText(dayChipIds[dow], Html.fromHtml(chipHtml1, Html.FROM_HTML_MODE_COMPACT))
                views.setViewVisibility(dayChipIds[dow], View.VISIBLE)
                views.setInt(dayChipIds[dow], "setBackgroundResource", chipBgRes)

                // 두 번째 칩
                if (matches.size >= 2 && maxChipsPerDay >= 2) {
                    val secondMatch = matches[1]
                    val chipHtml2 = "<font color='$chipTeamColor'>${secondMatch.blue}</font><font color='#F03E3E'>VS</font><font color='$chipTeamColor'>${secondMatch.red}</font>"
                    views.setTextViewText(dayChip2Ids[dow], Html.fromHtml(chipHtml2, Html.FROM_HTML_MODE_COMPACT))
                    views.setViewVisibility(dayChip2Ids[dow], View.VISIBLE)
                    views.setInt(dayChip2Ids[dow], "setBackgroundResource", chipBgRes)
                } else {
                    views.setViewVisibility(dayChip2Ids[dow], View.GONE)
                }

                // +N 표시
                val remaining = matches.size - maxChipsPerDay
                if (remaining > 0) {
                    views.setTextViewText(dayMoreIds[dow], "+$remaining")
                    views.setTextColor(dayMoreIds[dow], moreTextColor)
                    views.setViewVisibility(dayMoreIds[dow], View.VISIBLE)
                } else {
                    views.setViewVisibility(dayMoreIds[dow], View.GONE)
                }
            } else {
                views.setViewVisibility(dayChipIds[dow], View.GONE)
                views.setViewVisibility(dayChip2Ids[dow], View.GONE)
                views.setViewVisibility(dayMoreIds[dow], View.GONE)
            }
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
