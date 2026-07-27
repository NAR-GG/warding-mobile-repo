package com.warding.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.Calendar

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ScheduleRemoteViewsFactory(applicationContext)
    }
}

class ScheduleRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var data = CalendarWidgetData.empty()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        data = ScheduleWidgetProvider.loadCalendarData(context)
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

        val dayNumIds = intArrayOf(
            R.id.day0_num, R.id.day1_num, R.id.day2_num,
            R.id.day3_num, R.id.day4_num, R.id.day5_num, R.id.day6_num
        )
        val dayMatch1Ids = intArrayOf(
            R.id.day0_match1, R.id.day1_match1, R.id.day2_match1,
            R.id.day3_match1, R.id.day4_match1, R.id.day5_match1, R.id.day6_match1
        )
        val dayMatch2Ids = intArrayOf(
            R.id.day0_match2, R.id.day1_match2, R.id.day2_match2,
            R.id.day3_match2, R.id.day4_match2, R.id.day5_match2, R.id.day6_match2
        )
        val dayMoreIds = intArrayOf(
            R.id.day0_more, R.id.day1_more, R.id.day2_more,
            R.id.day3_more, R.id.day4_more, R.id.day5_more, R.id.day6_more
        )
        val dayCellIds = intArrayOf(
            R.id.day0, R.id.day1, R.id.day2,
            R.id.day3, R.id.day4, R.id.day5, R.id.day6
        )

        for (dow in 0..6) {
            val offset = week * 7 + dow - firstWd
            val dayNum = offset + 1

            val displayDay: Int
            val isCurrentMonth: Boolean
            val matches: List<MatchInfo>

            when {
                dayNum < 1 -> {
                    displayDay = prevDim + dayNum
                    isCurrentMonth = false
                    matches = emptyList()
                }
                dayNum > dim -> {
                    displayDay = dayNum - dim
                    isCurrentMonth = false
                    matches = emptyList()
                }
                else -> {
                    displayDay = dayNum
                    isCurrentMonth = true
                    matches = data.days[dayNum] ?: emptyList()
                }
            }

            // 날짜 숫자
            views.setTextViewText(dayNumIds[dow], "$displayDay")

            // 색상
            val isToday = isCurrentMonth && dayNum == todayDay
            val textColor = when {
                isToday -> Color.parseColor("#FFFF6B6B")
                dow == 6 -> Color.parseColor("#FFFFBCBC")
                else -> Color.WHITE
            }
            views.setTextColor(dayNumIds[dow], textColor)

            // 투명도 (이전/다음 달)
            val alpha = if (isCurrentMonth) 255 else 127
            views.setInt(dayCellIds[dow], "setAlpha", alpha)

            // 경기 칩 1
            if (matches.isNotEmpty()) {
                val m = matches[0]
                views.setTextViewText(dayMatch1Ids[dow], "${m.blue}VS${m.red}")
                views.setViewVisibility(dayMatch1Ids[dow], View.VISIBLE)
            } else {
                views.setViewVisibility(dayMatch1Ids[dow], View.GONE)
            }

            // 경기 칩 2
            if (matches.size >= 2) {
                val m = matches[1]
                views.setTextViewText(dayMatch2Ids[dow], "${m.blue}VS${m.red}")
                views.setViewVisibility(dayMatch2Ids[dow], View.VISIBLE)
            } else {
                views.setViewVisibility(dayMatch2Ids[dow], View.GONE)
            }

            // +N
            if (matches.size > 2) {
                views.setTextViewText(dayMoreIds[dow], "+${matches.size - 2}")
                views.setViewVisibility(dayMoreIds[dow], View.VISIBLE)
            } else {
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
