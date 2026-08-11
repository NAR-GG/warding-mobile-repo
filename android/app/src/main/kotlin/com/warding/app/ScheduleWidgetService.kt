package com.warding.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.Calendar

private const val TAG = "ScheduleWidgetSvc"

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        Log.d(TAG, "onGetViewFactory called")
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID
        )
        return ScheduleRemoteViewsFactory(applicationContext, appWidgetId)
    }
}

class ScheduleRemoteViewsFactory(
    private val context: Context,
    private val appWidgetId: Int
) : RemoteViewsService.RemoteViewsFactory {

    private var data = CalendarWidgetData.empty()
    private val isDark: Boolean = run {
        val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        nightMode == Configuration.UI_MODE_NIGHT_YES
    }

    // 요일 헤더(14dp) + widget_root 상하 패딩(12dp*2, schedule_widget.xml 기준)을 뺀
    // 나머지를 주(week) 수로 나눈 값이 캘린더 행이 배정된 공간에 남는 공백/잘림 없이
    // 정확히 맞아떨어지는 높이다. 최소값을 강제로 올리면(예: wrap_content 자연 높이보다
    // 크게) 오히려 마지막 주 행이 배정된 영역 밖으로 밀려나 잘릴 수 있어 하한선을 두지 않는다.
    private val chromeHeightDp = 14 + 24

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

    private fun rowHeightPx(): Int {
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return 0
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId)
        val grantedHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            ?.takeIf { it > 0 }
            ?: options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        if (grantedHeightDp <= 0) return 0
        val gridHeightDp = (grantedHeightDp - chromeHeightDp).coerceAtLeast(0)
        val weeks = data.weekCount().coerceAtLeast(1)
        val rowHeightDp = gridHeightDp / weeks
        val density = context.resources.displayMetrics.density
        return (rowHeightDp * density).toInt()
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_row)
        val rowHeight = rowHeightPx()
        if (rowHeight > 0) {
            views.setInt(R.id.row_root, "setMinimumHeight", rowHeight)
        }
        val week = position
        val firstWd = data.firstWeekday()
        val dim = data.daysInMonth()
        val prevDim = data.prevMonthDays()
        val now = Calendar.getInstance()
        val todayDay = if (now.get(Calendar.YEAR) == data.year &&
            now.get(Calendar.MONTH) + 1 == data.month
        ) now.get(Calendar.DAY_OF_MONTH) else -1

        // 색상 상수
        val defaultDayColor = if (isDark) Color.parseColor("#FFFFFFFF") else Color.parseColor("#FF000000")
        val sundayColor = if (isDark) Color.parseColor("#FF9672AC") else Color.parseColor("#FF6D2E92")
        val noMatchColor = if (isDark) Color.parseColor("#FFA6A7AB") else Color.parseColor("#FFA6A7AB")
        val nonCurrentMonthColor = if (isDark) Color.parseColor("#80FFFFFF") else Color.parseColor("#80000000")

        val dayNumIds = intArrayOf(
            R.id.day0_num, R.id.day1_num, R.id.day2_num,
            R.id.day3_num, R.id.day4_num, R.id.day5_num, R.id.day6_num
        )
        val dayDotIds = intArrayOf(
            R.id.day0_dot, R.id.day1_dot, R.id.day2_dot,
            R.id.day3_dot, R.id.day4_dot, R.id.day5_dot, R.id.day6_dot
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

            if (!isCurrentMonth) {
                // Not current month: empty text, hide dot
                views.setTextViewText(dayNumIds[dow], "")
                views.setViewVisibility(dayDotIds[dow], View.GONE)
                // Clear any background from previous recycled view
                views.setInt(dayNumIds[dow], "setBackgroundColor", Color.TRANSPARENT)
                continue
            }

            // Current month
            views.setTextViewText(dayNumIds[dow], "$displayDay")

            val isToday = dayNum == todayDay
            val hasMatches = data.days.containsKey(dayNum) && data.days[dayNum]!!.isNotEmpty()
            val isSunday = dow == data.sundayColumn

            if (isToday) {
                // Today: red text + background highlight (same in both modes)
                views.setTextColor(dayNumIds[dow], Color.parseColor("#FFFF6B6B"))
                views.setInt(dayNumIds[dow], "setBackgroundResource",
                    if (isDark) R.drawable.mini_today_bg else R.drawable.mini_today_bg_light)
                // Show dot if has matches
                views.setViewVisibility(dayDotIds[dow], if (hasMatches) View.VISIBLE else View.GONE)
            } else if (hasMatches) {
                // Has matches: colored text, dot visible
                val color = if (isSunday) sundayColor else defaultDayColor
                views.setTextColor(dayNumIds[dow], color)
                views.setInt(dayNumIds[dow], "setBackgroundColor", Color.TRANSPARENT)
                views.setViewVisibility(dayDotIds[dow], View.VISIBLE)
            } else {
                // No matches
                val color = if (isSunday) sundayColor else noMatchColor
                views.setTextColor(dayNumIds[dow], color)
                views.setInt(dayNumIds[dow], "setBackgroundColor", Color.TRANSPARENT)
                views.setViewVisibility(dayDotIds[dow], View.GONE)
            }
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
