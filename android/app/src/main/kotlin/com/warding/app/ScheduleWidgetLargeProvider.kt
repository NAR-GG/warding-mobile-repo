package com.warding.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.net.URL
import java.util.Calendar
import java.util.concurrent.Executors

private const val TAG = "ScheduleWidgetLarge"

class ScheduleWidgetLargeProvider : AppWidgetProvider() {

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
        // 캐시 재렌더링뿐 아니라 실제 네트워크 재조회도 트리거한다 (30분 주기 자동 갱신 대응).
        // 주의: onUpdate()는 시스템 주기 틱뿐 아니라 HomeWidget.updateWidget() 호출(버튼 탭 처리 결과 등)
        // 로도 재진입된다. 디바운스 없이 무조건 발사하면 갱신→onUpdate→갱신의 무한 루프가 생기므로,
        // 마지막 발사로부터 REFRESH_DEBOUNCE_MS 이상 지났을 때만 실제로 브로드캐스트한다.
        if (shouldTriggerBackgroundRefresh(context)) {
            try {
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("warding://widget/refresh")).send()
            } catch (e: android.app.PendingIntent.CanceledException) {
                Log.e(TAG, "refresh background intent failed", e)
            }
        }
    }

    // 사용자가 위젯 크기를 조절하면 행 높이를 새 크기에 맞게 다시 계산해야 하므로 재렌더링한다.
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
        private val executor = Executors.newSingleThreadExecutor()

        private const val REFRESH_DEBOUNCE_MS = 10 * 60 * 1000L // 10분 — 시스템 30분 주기보다 훨씬 짧지만, onUpdate() 재진입 체인(수 ms~수 초) 억제에는 충분히 길다.

        private fun shouldTriggerBackgroundRefresh(context: Context): Boolean {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val lastTriggeredAt = prefs.getLong("last_refresh_trigger_at", 0L)
            val now = System.currentTimeMillis()
            if (now - lastTriggeredAt < REFRESH_DEBOUNCE_MS) return false
            prefs.edit().putLong("last_refresh_trigger_at", now).apply()
            return true
        }

        private fun isDarkMode(context: Context): Boolean {
            val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            return nightMode == Configuration.UI_MODE_NIGHT_YES
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget_large)
            val calData = ScheduleWidgetProvider.loadCalendarData(context)
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val isDark = isDarkMode(context)

            // 배경
            views.setInt(R.id.widget_large_root, "setBackgroundResource",
                if (isDark) R.drawable.widget_background else R.drawable.widget_background_light)

            // 색상 상수
            val defaultTextColor = if (isDark) Color.WHITE else Color.parseColor("#101113")
            val weekdayHeaderColor = if (isDark) Color.WHITE else Color.BLACK
            val sundayColor = if (isDark) Color.parseColor("#9672AC") else Color.parseColor("#6D2E92")

            // 월 라벨: YY.MM 형식
            val yearShort = calData.year % 100
            val monthLabel = String.format("%02d.%02d", yearShort, calData.month)
            views.setTextViewText(R.id.large_month_label, monthLabel)
            views.setTextColor(R.id.large_month_label, defaultTextColor)

            // 화살표 아이콘: dark=white, light=dark
            views.setImageViewResource(R.id.large_prev_btn,
                if (isDark) R.drawable.ic_chevron_left else R.drawable.ic_chevron_left_dark)
            views.setImageViewResource(R.id.large_next_btn,
                if (isDark) R.drawable.ic_chevron_right else R.drawable.ic_chevron_right_dark)

            // 요일 헤더 — 텍스트 순서와 색을 설정에 맞춰 함께 갱신한다.
            val allLargeWdIds = intArrayOf(
                R.id.large_wd_mon, R.id.large_wd_tue, R.id.large_wd_wed, R.id.large_wd_thu,
                R.id.large_wd_fri, R.id.large_wd_sat, R.id.large_wd_sun
            )
            val orderedLabels = orderedWeekdayLabels(calData.weekStart)
            for (i in allLargeWdIds.indices) {
                views.setTextViewText(allLargeWdIds[i], orderedLabels[i])
                views.setTextColor(allLargeWdIds[i], if (i == calData.sundayColumn) sundayColor else weekdayHeaderColor)
            }

            // ListView RemoteAdapter 설정
            val intent = Intent(context, ScheduleWidgetLargeService::class.java)
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            intent.data = Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
            views.setRemoteAdapter(R.id.widget_large_calendar_grid, intent)

            // Prev/Next month deep links
            val year = calData.year
            val month = calData.month

            views.setOnClickPendingIntent(
                R.id.large_prev_btn,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("warding://widget/prev?year=$year&month=$month")
                )
            )

            views.setOnClickPendingIntent(
                R.id.large_next_btn,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("warding://widget/next?year=$year&month=$month")
                )
            )

            // 필터 아이콘: 필터 적용 시 그라데이션 보더
            val hasFilter = prefs.getBoolean("has_filter", false)
            val filterBgRes = if (hasFilter) {
                if (isDark) R.drawable.filter_circle_gradient_border else R.drawable.filter_circle_gradient_border_light
            } else {
                if (isDark) R.drawable.filter_circle_bg else R.drawable.filter_circle_bg_light
            }
            views.setImageViewResource(R.id.large_filter_bg, filterBgRes)

            // 필터 아이콘 이미지
            views.setImageViewResource(R.id.large_filter_icon,
                if (isDark) R.drawable.ic_filter else R.drawable.ic_filter_dark)

            // 필터 클릭 → 앱 열고 필터 모달 자동 오픈
            val filterIntent = Intent(Intent.ACTION_VIEW, Uri.parse("warding://widget/filter"))
            filterIntent.setPackage(context.packageName)
            val filterPending = android.app.PendingIntent.getActivity(
                context, 3, filterIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.large_filter_btn, filterPending)

            // 팀 로고: 선택 시 그라데이션 보더
            val teamSelected = prefs.getBoolean("team_selected", false)
            val teamBgRes = if (teamSelected) {
                if (isDark) R.drawable.team_circle_gradient_border else R.drawable.team_circle_gradient_border_light
            } else {
                if (isDark) R.drawable.team_circle_bg else R.drawable.team_circle_bg_light
            }
            views.setImageViewResource(R.id.large_team_bg, teamBgRes)

            // 팀 클릭 → 앱을 열지 않고 백그라운드에서 응원팀 필터 ON/OFF 토글
            views.setOnClickPendingIntent(
                R.id.large_team_btn,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("warding://widget/team"))
            )

            // 앱 열기 인텐트
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_large_root, pendingIntent)
            }

            // 먼저 뷰 업데이트 (팀 로고 로딩 전)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_large_calendar_grid)

            // 팀 로고 이미지 비동기 로딩
            val teamImageUrl = prefs.getString("team_image_url", null)
            if (!teamImageUrl.isNullOrEmpty()) {
                executor.execute {
                    try {
                        val url = URL(teamImageUrl)
                        val connection = url.openConnection()
                        connection.connectTimeout = 5000
                        connection.readTimeout = 5000
                        val inputStream = connection.getInputStream()
                        val bitmap = BitmapFactory.decodeStream(inputStream)
                        inputStream.close()
                        if (bitmap != null) {
                            // 원형 크롭
                            val circularBitmap = getCircularBitmap(bitmap)
                            val updatedViews = RemoteViews(context.packageName, R.layout.schedule_widget_large)
                            updatedViews.setImageViewBitmap(R.id.large_team_logo, circularBitmap)
                            appWidgetManager.partiallyUpdateAppWidget(appWidgetId, updatedViews)
                            Log.d(TAG, "Team logo loaded successfully")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to load team logo: $e")
                    }
                }
            }
        }

        private fun getCircularBitmap(bitmap: Bitmap): Bitmap {
            val size = minOf(bitmap.width, bitmap.height)
            val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(output)
            val paint = android.graphics.Paint().apply {
                isAntiAlias = true
                shader = android.graphics.BitmapShader(
                    bitmap,
                    android.graphics.Shader.TileMode.CLAMP,
                    android.graphics.Shader.TileMode.CLAMP
                )
            }
            val r = size / 2f
            canvas.drawCircle(r, r, r, paint)
            return output
        }
    }
}
