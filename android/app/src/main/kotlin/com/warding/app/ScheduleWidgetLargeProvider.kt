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
        // 디바운스·재진입 처리는 소·중 위젯과 공유하는 [WidgetRefreshTrigger] 가 맡는다.
        WidgetRefreshTrigger.request(context)
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

        private fun isDarkMode(context: Context): Boolean {
            val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
            return nightMode == Configuration.UI_MODE_NIGHT_YES
        }

        /** 이미 받아 둔 응원팀 로고(원형 크롭 완료). URL 이 키다. */
        private val logoCache = java.util.concurrent.ConcurrentHashMap<String, Bitmap>()

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = buildViews(context, appWidgetManager, appWidgetId, null)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_large_calendar_grid)
        }

        /**
         * 위젯 뷰를 만든다.
         *
         * [teamLogo] 가 주어지면 그 비트맵을 응원팀 자리에 그린다. 없으면
         * 캐시를 보고, 그것도 없으면 비동기로 받아 온 뒤 이 함수를 다시 불러
         * 전체 뷰를 갱신한다.
         */
        private fun buildViews(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            teamLogo: Bitmap?,
        ): RemoteViews {
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

            // 월 이동은 [WidgetMonthShiftReceiver] 가 받는다. 거기서 저장된 월을
            // 먼저 옮겨 위젯을 다시 그린 뒤 실제 조회를 요청한다 — Dart 백그라운드
            // 콜백은 JobIntentService 로 도는데 안드로이드가 즉시 실행하지 않아
            // (실측 2~3초) 버튼을 눌러도 한참 반응이 없어 보였다.
            views.setOnClickPendingIntent(
                R.id.large_prev_btn,
                android.app.PendingIntent.getBroadcast(
                    context,
                    6,
                    Intent(context, WidgetMonthShiftReceiver::class.java)
                        .setAction(WidgetMonthShiftReceiver.ACTION_PREV),
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE,
                ),
            )

            views.setOnClickPendingIntent(
                R.id.large_next_btn,
                android.app.PendingIntent.getBroadcast(
                    context,
                    7,
                    Intent(context, WidgetMonthShiftReceiver::class.java)
                        .setAction(WidgetMonthShiftReceiver.ACTION_NEXT),
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE,
                ),
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

            // 필터 클릭 → 앱 열고 필터 모달 자동 오픈.
            //
            // 앱을 여는 인텐트는 위젯 본체(캘린더)를 누를 때와 똑같은 것을 쓴다.
            // 예전에는 Intent(ACTION_VIEW) 를 따로 만들어 딥링크로 보냈는데,
            // 그 인텐트에는 런처 플래그가 없어 기존 태스크를 재사용하지 못하고
            // 새 태스크를 시작했다 — 캘린더를 누르면 바로 열리는데 필터만
            // 스플래시부터 도는 차이가 여기서 났고, 그 새 태스크에서는 딥링크가
            // UI 준비 전에 도착해 필터도 열리지 않았다.
            //
            // 앱을 여는 인텐트는 위젯 본체(캘린더)를 누를 때와 똑같은 런처
            // 인텐트를 쓰고, 딥링크 데이터만 얹는다.
            //
            // 예전에는 Intent(ACTION_VIEW) 를 새로 만들었는데 런처 플래그가 없어
            // 기존 태스크를 재사용하지 못하고 새 태스크를 시작했다 — 캘린더는
            // 바로 열리는데 필터만 스플래시부터 돌던 차이가 여기서 났고, 그 새
            // 태스크에서는 딥링크가 UI 준비 전에 도착해 필터도 열리지 않았다.
            //
            // 필터 버튼은 딥링크를 쓰지 않는다.
            //
            // 딥링크(ACTION_VIEW + data)로 열면 launchMode=singleTop 이어도
            // 액티비티가 재생성된다 — Android 는 data 가 다른 인텐트를 다른
            // 요청으로 보기 때문이다. 그러면 main() 이 다시 돌아 스플래시부터
            // 화면이 뜨고, 딥링크는 UI 준비 전에 도착해 필터가 열리지 않는다.
            // (캘린더 본체를 누를 때는 딥링크가 없어 이 문제가 없었다.)
            //
            // 그래서 앱은 캘린더와 똑같은 런처 인텐트로 열고, "필터를 열어라"는
            // 공유 저장소에 남긴다. 앱은 뜨는 즉시·복귀 즉시 이 값을 보고 연다
            // (HomeWidgetService.consumePendingAction).
            //
            // 표시를 남기는 것은 클릭 시점이어야 하므로 위젯을 그릴 때가 아니라
            // 별도 브로드캐스트(WidgetActionReceiver)에서 한다.
            views.setOnClickPendingIntent(
                R.id.large_filter_btn,
                android.app.PendingIntent.getBroadcast(
                    context,
                    5,
                    Intent(context, WidgetActionReceiver::class.java)
                        .setAction(WidgetActionReceiver.ACTION_OPEN_FILTER),
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE,
                ),
            )

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

            // 앱을 아직 안 켜서 데이터를 받아올 수 없으면 안내를 겹친다.
            WidgetRefreshTrigger.applyLockedOverlay(
                context,
                views,
                hasData = calData.days.isNotEmpty(),
            )

            // 저장된 캘린더가 아직 없으면(최초 배치) 디바운스를 무시하고 바로 받아온다.
            // 사용자가 prev/next 로 다른 달을 보고 있을 수도 있으므로, "이번 달이
            // 아니다"는 것만으로는 재조회하지 않는다 — 보고 있던 달로 되돌려 버린다.
            if (prefs.getString("calendar_data", null) == null) {
                WidgetRefreshTrigger.request(context, force = true)
            }

            // 응원팀 로고
            val teamImageUrl = prefs.getString("team_image_url", null)
            val logo = teamLogo ?: teamImageUrl?.let { logoCache[it] }
            if (logo != null) {
                views.setImageViewBitmap(R.id.large_team_logo, logo)
            } else if (!teamImageUrl.isNullOrEmpty()) {
                // 아직 못 받았으면 비동기로 받아 두고, 받은 뒤 전체 뷰를 다시
                // 만들어 갱신한다.
                //
                // 예전에는 로고만 담은 RemoteViews 를 partiallyUpdateAppWidget 로
                // 얹었는데, 그건 직전 updateAppWidget 뒤에만 반영된다. 위젯 갱신이
                // 연달아 도는 동안에는 곧바로 다음 전체 갱신에 덮여 사라졌다
                // (로그에는 "loaded successfully" 가 찍히는데 화면엔 안 보이던 원인).
                executor.execute {
                    try {
                        val url = URL(teamImageUrl)
                        val connection = url.openConnection()
                        connection.connectTimeout = 5000
                        connection.readTimeout = 5000
                        val loaded = connection.getInputStream().use {
                            BitmapFactory.decodeStream(it)
                        } ?: return@execute
                        val circular = getCircularBitmap(loaded)
                        logoCache[teamImageUrl] = circular
                        appWidgetManager.updateAppWidget(
                            appWidgetId,
                            buildViews(context, appWidgetManager, appWidgetId, circular),
                        )
                        Log.d(TAG, "Team logo applied")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to load team logo: $e")
                    }
                }
            }

            return views
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
