package com.warding.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Paint
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
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

    // 런처가 위젯 크기를 재계산해 배정 옵션을 다시 보낼 때(리사이즈뿐 아니라, 이 기기에서는
    // 다크/라이트 테마 전환 시에도 발생) 재렌더링해 최신 테마 색상을 반영한다.
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
            val todayData = ScheduleWidgetProvider.loadTodayData(context)
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

            // 경기 리스트 (미디움 위젯과 동일한 선택 로직: 지난 경기 최대 1개 + 실제 카드 최대 2개)
            views.removeAllViews(R.id.small_matches_container)
            val matches = todayData.matches
            val displayResult = selectDisplayMatches(matches)

            for (displayMatch in displayResult.rows) {
                val m = displayMatch.match
                val row = RemoteViews(context.packageName, R.layout.match_row_small)
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

                views.addView(R.id.small_matches_container, row)
            }

            if (displayResult.overflowCount > 0) {
                val moreRow = RemoteViews(context.packageName, R.layout.match_row_small)
                moreRow.setTextViewText(R.id.match_time, "+${displayResult.overflowCount}")
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
    }
}
