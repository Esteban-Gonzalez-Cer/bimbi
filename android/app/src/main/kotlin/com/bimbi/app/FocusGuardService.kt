package com.bimbi.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.text.format.DateFormat
import java.util.Date

/**
 * Soft Focus shield. While a Focus session or a daily limit needs it, this
 * foreground service reads Usage Access events about once a second and covers
 * a chosen app with [ShieldOverlay]. It is a pause screen, not a lock: the
 * person can revoke either permission or stop Bimbi in Android settings.
 */
class FocusGuardService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var store: GuardStore
    private lateinit var overlay: ShieldOverlay
    private var tracker: UsageTracker? = null
    private var exempt: Set<String> = emptySet()
    private var foreground = false
    private var lastNotice = ""

    private val tick = object : Runnable {
        override fun run() {
            check()
            if (foreground) handler.postDelayed(this, POLL_MS)
        }
    }

    private val screen = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            handler.removeCallbacks(tick)
            if (intent.action == Intent.ACTION_SCREEN_OFF) overlay.hide() else handler.post(tick)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        store = GuardStore(this)
        overlay = ShieldOverlay(this)
        exempt = FocusGuard.exemptions(this)
        registerReceiver(screen, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val rules = store.load()
        if (!foreground) {
            val notice = notification(rules)
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIFICATION, notice, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFICATION, notice)
            }
            foreground = true
        }
        exempt = FocusGuard.exemptions(this)
        tracker = null // rules or the clock may have changed; recount today
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    private fun check() {
        val now = System.currentTimeMillis()
        val rules = store.load()
        if (!FocusGuard.usageAllowed(this) || !FocusGuard.overlayAllowed(this)) return stop("permission_revoked")
        if (!rules.hasWork(now)) {
            if (rules.focusUntil != null) store.save(rules.copy(focusUntil = null))
            return stop("nothing_to_enforce")
        }
        if (!getSystemService(PowerManager::class.java).isInteractive) return overlay.hide()
        val usage = count(now)
        val shield = shieldFor(usage.foreground(), rules, usage.usage(now), now) { it in exempt }
        if (shield == null) overlay.hide() else overlay.show(shield, now)
        updateNotice(rules)
    }

    /** Applies only the events since the last tick; recounts on a new day or a clock change. */
    private fun count(now: Long): UsageTracker {
        val midnight = FocusGuard.midnight(now)
        var current = tracker
        if (current == null || now < current.cursor - 1_000 || midnight < current.start) {
            current = UsageTracker(midnight).also { FocusGuard.fold(this, it, midnight, now) }
            tracker = current
            return current
        }
        if (midnight > current.start) current.rollOver(midnight)
        FocusGuard.fold(this, current, current.cursor + 1, now)
        return current
    }

    private fun updateNotice(rules: GuardRules) {
        val text = noticeText(rules)
        if (text == lastNotice) return
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(rules))
    }

    private fun noticeText(rules: GuardRules): String {
        val now = System.currentTimeMillis()
        val until = rules.focusUntil?.takeIf { rules.focusActive(now) }
        return when {
            until != null -> "Pausing ${rules.focusApps.size} apps until ${DateFormat.getTimeFormat(this).format(Date(until))}"
            else -> "Daily limits on for ${rules.limits.size} apps"
        }
    }

    private fun notification(rules: GuardRules): Notification {
        channel(this)
        lastNotice = noticeText(rules)
        val open = PendingIntent.getActivity(
            this, 201, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_bimbi)
            .setColor(getColor(R.color.bimbi_lilac_accent))
            .setContentTitle("Focus shield on")
            .setContentText(lastNotice)
            .setContentIntent(open)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_STATUS)
            .build()
    }

    private fun stop(reason: String) {
        store.recordStop(reason)
        overlay.hide()
        handler.removeCallbacks(tick)
        if (foreground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            foreground = false
        }
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        overlay.hide()
        runCatching { unregisterReceiver(screen) }
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "bimbi_focus_shield"
        private const val NOTIFICATION = 4402
        private const val POLL_MS = 1_000L

        fun channel(context: Context) {
            val channel = NotificationChannel(CHANNEL, "Focus shield", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Shows while Bimbi pauses apps during Focus or after a daily limit."
                setShowBadge(false)
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        fun start(context: Context) {
            runCatching { context.startForegroundService(Intent(context, FocusGuardService::class.java)) }
                .onFailure { GuardStore(context).recordStop("start_failed") }
        }
    }
}
