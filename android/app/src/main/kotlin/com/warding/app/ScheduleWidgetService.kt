package com.warding.app

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
        return ScheduleRemoteViewsFactory(applicationContext)
    }
}

class ScheduleRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var data = CalendarWidgetData.empty()
    private val isDark: Boolean = run {
        val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        nightMode == Configuration.UI_MODE_NIGHT_YES
    }

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

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_row)
        val week = position
        val firstWd = data.firstWeekday()
        val dim = data.daysInMonth()
        val prevDim = data.prevMonthDays()
        val now = Calendar.getInstance()
        val todayDay = if (now.get(Calendar.YEAR) == data.year &&
            now.get(Calendar.MONTH) + 1 == data.month
        ) now.get(Calendar.DAY_OF_MONTH) else -1

        // 색상 상수
        val defaultDayColor = if (isDark) Color.WHITE else Color.BLACK
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
            val isSunday = dow == 6

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
