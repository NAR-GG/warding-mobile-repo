package com.warding.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.Base64
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter 에서 실시간 경기 알림을 제어하는 MethodChannel 핸들러.
 *
 * iOS 의 Live Activity 에 대응하는 Android 구현이다. 커스텀 레이아웃을 붙인
 * 진행 중(ongoing) 알림으로 같은 화면을 재현하고, Android 16(API 36)+ 에서는
 * Live Update 로 승격해 상태바 칩까지 노출한다. 구버전은 일반 진행 중 알림으로
 * 그대로 동작한다.
 *
 * 채널·메서드 이름은 iOS 와 동일해 Dart 쪽 코드를 그대로 공유한다.
 * - `isSupported` → Bool
 * - `start(payload)` → 알림 표시, 식별자 반환
 * - `update(payload)` → 같은 알림 ID 로 다시 표시(내용 갱신)
 * - `end(payload)` → 알림 제거
 * - `endAll` → 알림 제거
 */
class LiveActivityPlugin(private val context: Context) {

    companion object {
        const val CHANNEL_NAME = "com.warding.app/live_activity"

        /**
         * 알림 채널 ID. 사용자가 개별로 끌 수 있게 FCM 채널과 분리한다.
         *
         * 이미 만들어진 채널은 중요도를 코드로 못 바꾼다. Live Update 승격에
         * 필요한 IMPORTANCE_HIGH 를 적용하려고 v2 로 새로 발급했다.
         */
        private const val NOTIFICATION_CHANNEL_ID = "warding_live_match_v2"

        /** 알림 ID. 동시에 하나만 유지하므로 고정값을 쓴다. */
        private const val NOTIFICATION_ID = 20260803

        /**
         * `Notification.FLAG_PROMOTED_ONGOING` (Android 16 / API 36).
         *
         * 이 플래그가 붙은 진행 중 알림은 Live Update 로 승격돼 상태바 칩과
         * 잠금화면 상단 고정을 받는다. SDK 에 공개 상수로 노출되지 않아
         * 값을 직접 적는다(플랫폼 정의값 262144).
         */
        private const val FLAG_PROMOTED_ONGOING = 262144

        fun register(context: Context, messenger: BinaryMessenger): LiveActivityPlugin {
            val plugin = LiveActivityPlugin(context)
            MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
                plugin.handle(call, result)
            }
            return plugin
        }
    }

    /** 현재 알림에 실린 정적 정보. update 시 재사용한다. */
    private var config: Map<String, Any?> = emptyMap()

    /** 진행 중 세트의 크로노미터 기준 시각(SystemClock.elapsedRealtime 기준). */
    private var chronometerBase: Long = 0L

    /** 기준 시각이 어느 세트의 것인지. 세트가 바뀌면 다시 잡는다. */
    private var timedSet: Int? = null

    private val notificationManager: NotificationManagerCompat
        get() = NotificationManagerCompat.from(context)

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "start" -> start(call.arguments as? Map<String, Any?> ?: emptyMap(), result)
            "update" -> update(call.arguments as? Map<String, Any?> ?: emptyMap(), result)
            "end" -> { cancel(); result.success(true) }
            "endAll" -> { cancel(); result.success(true) }
            else -> result.notImplemented()
        }
    }

    /** 알림을 띄울 수 있는 상태인지(권한 허용 여부). */
    private fun isSupported(): Boolean = notificationManager.areNotificationsEnabled()

    private fun start(args: Map<String, Any?>, result: MethodChannel.Result) {
        if (!isSupported()) {
            result.error("disabled", "알림 권한이 없습니다.", null)
            return
        }
        config = args
        timedSet = null
        show(args)
        result.success(NOTIFICATION_ID.toString())
    }

    private fun update(args: Map<String, Any?>, result: MethodChannel.Result) {
        if (config.isEmpty()) {
            // start 없이 update 가 오면 표시할 정적 정보가 없다.
            result.success(false)
            return
        }
        // 정적 정보(config) 위에 갱신된 상태값만 덮어쓴다.
        show(config + args)
        result.success(true)
    }

    private fun cancel() {
        notificationManager.cancel(NOTIFICATION_ID)
        config = emptyMap()
        timedSet = null
    }

    // ── 알림 구성 ────────────────────────────────

    private fun show(data: Map<String, Any?>) {
        createChannelIfNeeded()

        val phase = data["phase"] as? String ?: "playing"
        val views = buildViews(data, phase)

        val ongoing = phase != "matchEnded"
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            // 진행 중 알림 — 스와이프로 지워지지 않게 한다.
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            // Live Update 로 승격되려면 진행 중인 이벤트 성격을 명시해야 한다.
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(deepLinkIntent(data, rating = false))
            .apply { setShortCriticalTextIfAvailable(this, shortStatus(data)) }
            .build()

        promoteToLiveUpdate(notification, ongoing)

        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS 권한이 취소된 경우.
        }
    }

    /**
     * Android 16(API 36)+ 에서 알림을 Live Update 로 승격한다.
     *
     * 승격되면 상태바 칩·잠금화면 상단 고정 등 iOS Live Activity 에 가까운
     * 대우를 받는다. 그 미만 버전에서는 플래그가 없어 일반 진행 중 알림으로
     * 그대로 동작한다(레이아웃·동작은 동일).
     */
    private fun promoteToLiveUpdate(notification: Notification, ongoing: Boolean) {
        if (Build.VERSION.SDK_INT < 36 || !ongoing) return
        notification.flags = notification.flags or FLAG_PROMOTED_ONGOING
    }

    /**
     * 상태바 칩 문구를 지정한다(Android 16+ / androidx.core 1.17+).
     *
     * 해당 API 가 없는 환경에서도 빌드·실행이 깨지지 않도록 리플렉션으로 부른다.
     */
    private fun setShortCriticalTextIfAvailable(
        builder: NotificationCompat.Builder,
        text: String,
    ) {
        runCatching {
            NotificationCompat.Builder::class.java
                .getMethod("setShortCriticalText", String::class.java)
                .invoke(builder, text)
        }
    }

    /** 상태바 칩에 들어갈 짧은 텍스트 — "0 : 0" 형태의 현재 스코어. */
    private fun shortStatus(data: Map<String, Any?>): String {
        val a = (data["scoreA"] as? Number)?.toInt() ?: 0
        val b = (data["scoreB"] as? Number)?.toInt() ?: 0
        return "$a : $b"
    }

    /** 상태별 레이아웃을 만들고 데이터를 채운다. */
    private fun buildViews(data: Map<String, Any?>, phase: String): RemoteViews {
        val layout = when (phase) {
            "setEnded" -> R.layout.live_match_set_ended
            "matchEnded" -> R.layout.live_match_match_ended
            else -> R.layout.live_match_playing
        }
        val views = RemoteViews(context.packageName, layout)

        val setNumber = (data["setNumber"] as? Number)?.toInt() ?: 1
        val teamACode = data["teamACode"] as? String ?: ""
        val teamBCode = data["teamBCode"] as? String ?: ""
        val league = data["leagueName"] as? String ?: ""

        views.setImageViewResource(R.id.live_logo, R.drawable.live_warding_logo)

        when (phase) {
            "playing" -> bindPlaying(views, data, setNumber, league)
            "setEnded" -> bindSetEnded(views, data, setNumber, teamACode, teamBCode, league)
            else -> bindMatchEnded(views, data, setNumber, teamACode, teamBCode, league)
        }
        return views
    }

    private fun bindPlaying(
        views: RemoteViews,
        data: Map<String, Any?>,
        setNumber: Int,
        league: String,
    ) {
        views.setTextViewText(R.id.live_set_label, "SET $setNumber - ")
        views.setTextViewText(R.id.live_league, league)

        // 세트가 바뀌면 경과 시간 기준점을 새로 잡는다.
        if (timedSet != setNumber) {
            timedSet = setNumber
            val startedAtMillis = (data["setStartedAtMillis"] as? Number)?.toLong()
            chronometerBase = if (startedAtMillis != null) {
                // 벽시계 → elapsedRealtime 기준으로 환산한다.
                SystemClock.elapsedRealtime() - (System.currentTimeMillis() - startedAtMillis)
            } else {
                SystemClock.elapsedRealtime()
            }
        }
        views.setChronometer(R.id.live_chronometer, chronometerBase, null, true)

        bindScore(views, data)
        bindTeamNames(views, data)
    }

    private fun bindSetEnded(
        views: RemoteViews,
        data: Map<String, Any?>,
        setNumber: Int,
        teamACode: String,
        teamBCode: String,
        league: String,
    ) {
        views.setTextViewText(R.id.live_ended_label, "SET $setNumber 종료")
        views.setTextViewText(
            R.id.live_next_set_notice,
            "SET ${setNumber}이 종료되었습니다. SET ${setNumber + 1} 준비 중입니다.",
        )
        views.setTextViewText(R.id.live_league, league)
        views.setTextViewText(R.id.live_versus, "$teamACode VS $teamBCode")
        views.setTextViewText(R.id.live_rating_label, "SET $setNumber 평점 남기기")

        bindLogos(views, data)
        bindHearts(views, data, teamACode, teamBCode)

        // 평점 영역만 선수 평점 탭으로 딥링크한다.
        views.setOnClickPendingIntent(
            R.id.live_rating_prompt,
            deepLinkIntent(data, rating = true),
        )
    }

    private fun bindMatchEnded(
        views: RemoteViews,
        data: Map<String, Any?>,
        setNumber: Int,
        teamACode: String,
        teamBCode: String,
        league: String,
    ) {
        views.setTextViewText(
            R.id.live_ended_label,
            "$teamACode VS $teamBCode 마지막 세트가 종료됐습니다.",
        )
        views.setTextViewText(R.id.live_league, league)
        views.setTextViewText(R.id.live_rating_label, "SET $setNumber 평점 남기기")

        bindScore(views, data)
        bindTeamNames(views, data)

        views.setOnClickPendingIntent(
            R.id.live_footer,
            deepLinkIntent(data, rating = true),
        )
    }

    private fun bindScore(views: RemoteViews, data: Map<String, Any?>) {
        val a = (data["scoreA"] as? Number)?.toInt() ?: 0
        val b = (data["scoreB"] as? Number)?.toInt() ?: 0
        views.setTextViewText(R.id.live_score_a, a.toString())
        views.setTextViewText(R.id.live_score_b, b.toString())
        bindLogos(views, data)
    }

    private fun bindTeamNames(views: RemoteViews, data: Map<String, Any?>) {
        views.setTextViewText(R.id.live_team_a_name, data["teamAName"] as? String ?: "")
        views.setTextViewText(R.id.live_team_b_name, data["teamBName"] as? String ?: "")
    }

    private fun bindLogos(views: RemoteViews, data: Map<String, Any?>) {
        decodeLogo(data["teamALogoBase64"] as? String)?.let {
            views.setImageViewBitmap(R.id.live_team_a_logo, it)
        }
        decodeLogo(data["teamBLogoBase64"] as? String)?.let {
            views.setImageViewBitmap(R.id.live_team_b_logo, it)
        }
    }

    /** 응원 팀 로고에만 하트를 보인다. */
    private fun bindHearts(
        views: RemoteViews,
        data: Map<String, Any?>,
        teamACode: String,
        teamBCode: String,
    ) {
        val favorite = data["favoriteTeamCode"] as? String
        views.setViewVisibility(
            R.id.live_team_a_heart,
            if (favorite != null && favorite == teamACode) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.live_team_b_heart,
            if (favorite != null && favorite == teamBCode) View.VISIBLE else View.GONE,
        )
    }

    private fun decodeLogo(base64: String?): Bitmap? {
        if (base64.isNullOrEmpty()) return null
        return try {
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: IllegalArgumentException) {
            null
        }
    }

    /**
     * 알림을 탭했을 때 열 딥링크.
     *
     * iOS 와 같은 스킴을 쓴다: `warding://match/{matchId}[?tab=rating&set=N]`
     */
    private fun deepLinkIntent(data: Map<String, Any?>, rating: Boolean): PendingIntent {
        val matchId = data["matchId"] as? String ?: ""
        val setNumber = (data["setNumber"] as? Number)?.toInt() ?: 1
        val uri = if (rating) {
            "warding://match/$matchId?tab=rating&set=$setNumber"
        } else {
            "warding://match/$matchId"
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
            setPackage(context.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        // rating 여부에 따라 다른 PendingIntent 가 되도록 requestCode 를 나눈다.
        return PendingIntent.getActivity(
            context,
            if (rating) 1 else 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return

        // Live Update 로 승격되려면 채널 중요도가 HIGH 여야 한다.
        // 소리·진동은 꺼서 스코어가 바뀔 때마다 방해하지 않게 한다.
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "실시간 경기",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "진행 중인 경기의 스코어를 실시간으로 보여줍니다."
            setShowBadge(false)
            enableVibration(false)
            enableLights(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }
}
