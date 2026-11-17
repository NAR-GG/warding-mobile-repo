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

    // 날짜 셀 안에서 칩이 아닌 부분(날짜 숫자 텍스트 + 상하 패딩) 예상 높이 —
    // schedule_widget_large_row.xml 기준(10sp 텍스트 줄높이 약 12dp + paddingTop/Bottom 2dp씩).
    private val cellChromeHeightDp = 16
    // 칩 한 줄 높이(13dp) + 위 마진(1dp) — 같은 XML 기준.
    private val chipRowHeightDp = 14

    // "+N" 오버플로 줄(10sp 텍스트 ≈ 12dp)의 높이. 칩과 별도로 한 줄을 더
    // 차지하는데 예전엔 이 몫을 빼지 않아, 칩 2개 + "+N" 이 3단으로 쌓이면
    // 셀이 계산한 행 높이를 넘겨 마지막 주가 잘렸다.
    private val moreRowHeightDp = 12


    private val dayCellIds = intArrayOf(
        R.id.large_day0_cell, R.id.large_day1_cell, R.id.large_day2_cell,
        R.id.large_day3_cell, R.id.large_day4_cell, R.id.large_day5_cell, R.id.large_day6_cell
    )

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
     * 남는 공백 없이 위젯 전체 높이를 채우도록 한 행이 가져야 할 높이(dp)를 계산한다.
     * 옵션을 못 읽거나 계산값이 0 이하면 0을 반환해 레이아웃 XML의 기본(minHeight=54dp)을 그대로 쓴다.
     */
    private fun rowHeightDp(): Int {
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return 0
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId)
            ?: return 0
        // 세로 모드에서 실제로 배정되는 높이는 MAX_HEIGHT 에 가깝다. MIN_HEIGHT 만
        // 보면(예전 동작) 실제보다 낮게 잡혀, 6주짜리 달에서 마지막 주가 배정
        // 영역 밖으로 밀려 잘렸다. 미니 캘린더 쪽(ScheduleWidgetService)과 같은
        // 기준을 쓴다.
        val grantedHeightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
            .takeIf { it > 0 }
            ?: options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        if (grantedHeightDp <= 0) return 0
        val gridHeightDp = (grantedHeightDp - chromeHeightDp).coerceAtLeast(0)
        if (gridHeightDp <= 0) return 0
        val weeks = data.weekCount().coerceAtLeast(1)
        return gridHeightDp / weeks
    }

    private fun rowHeightPx(rowHeightDp: Int): Int {
        if (rowHeightDp <= 0) return 0
        val density = context.resources.displayMetrics.density
        return (rowHeightDp * density).toInt()
    }

    /**
     * 행 높이가 실제로 칩 2개를 담을 여유가 있는지로 하루 최대 칩 수를 정한다.
     * 예전엔 "6주짜리 달이면 무조건 1개"로 고정해서, 위젯이 커서 6주라도 공간이
     * 충분한 경우까지 칩을 숨기는 문제가 있었다. rowHeightDp 를 못 구했으면(위젯
     * 옵션 미제공) 기존과 같이 주 수 기준으로 대체한다.
     */
    private fun maxChipsPerDay(rowHeightDp: Int): Int {
        if (rowHeightDp <= 0) return if (data.weekCount() >= 6) 1 else 2
        // 셀의 XML minHeight 는 getViewAt 에서 계산된 행 높이로 덮어쓰므로,
        // 실제로 쓸 수 있는 높이는 계산값 그대로다.
        //
        // 칩을 우선한다 — 경기 일정 위젯이라 "몇 경기"보다 "어떤 경기"가 중요하다.
        // "+N" 은 [showMoreRow] 가 남는 높이를 보고 따로 정한다.
        val availableForChips = rowHeightDp - cellChromeHeightDp
        return (availableForChips / chipRowHeightDp).coerceIn(1, 2)
    }

    /**
     * "+N" 줄을 그릴 여유가 있는지.
     *
     * 칩을 먼저 배치하고 남는 높이로 판단한다. 폴더블 펼침처럼 셀이 커져 행당
     * 높이가 32dp 까지 줄면 날짜(16) + 칩(13) 만으로 29dp 라 "+N" 자리가 없다.
     * 이때 "+N" 을 함께 그리면 셀이 배정 높이를 넘겨 마지막 주가 잘린다.
     */
    private fun showMoreRow(rowHeightDp: Int, chipCount: Int): Boolean {
        if (rowHeightDp <= 0) return true
        val used = cellChromeHeightDp + chipRowHeightDp * chipCount
        return rowHeightDp - used >= moreRowHeightDp
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_large_row)
        val rowHeightDp = rowHeightDp()
        val rowHeight = rowHeightPx(rowHeightDp)
        if (rowHeight > 0) {
            views.setInt(R.id.large_row_root, "setMinimumHeight", rowHeight)
            // 날짜 셀의 XML minHeight(54dp)도 함께 낮춘다. 행에만 걸면 셀이
            // 자기 하한을 고집해 행이 밀려나고, 6주짜리 달에서 마지막 주가
            // 배정 영역 밖으로 잘린다.
            for (cellId in dayCellIds) {
                views.setInt(cellId, "setMinimumHeight", rowHeight)
            }
        }
        val week = position
        val firstWd = data.firstWeekday()
        val dim = data.daysInMonth()
        val prevDim = data.prevMonthDays()
        val now = Calendar.getInstance()
        val todayDay = if (now.get(Calendar.YEAR) == data.year &&
            now.get(Calendar.MONTH) + 1 == data.month
        ) now.get(Calendar.DAY_OF_MONTH) else -1

        val maxChipsPerDay = maxChipsPerDay(rowHeightDp)

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

                // +N 표시. 칩을 배치하고 자리가 남을 때만 그린다.
                val shownChips = minOf(matches.size, maxChipsPerDay)
                val remaining = matches.size - shownChips
                if (remaining > 0 && showMoreRow(rowHeightDp, shownChips)) {
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
