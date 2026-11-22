package com.bimbi.app

import android.app.*
import android.content.*
import android.media.*
import android.os.*

class AlarmService : Service() {
    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val accessWatch = object : Runnable {
        override fun run() {
            if (!AlarmEngine(this@AlarmService).notificationsAllowed()) {
                stopForNotificationDenial()
            } else handler.postDelayed(this, 1_000)
        }
    }
    private fun stopForNotificationDenial() {
        // Also cancel a pending recurrence: a permission change must not
        // leave an audible alert running without its dismissal surface.
        AlarmEngine(this).apply {
            cancel()
            event("notification_permission_revoked_alert_stopped")
        }
        stopSelf()
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        AlarmEngine.channels(this)
        // Recheck at the service boundary to cover revocation after receipt.
        if (!AlarmEngine(this).notificationsAllowed()) {
            stopForNotificationDenial()
            return START_NOT_STICKY
        }
        startForeground(200, notification(this))
        if (player == null) {
            try {
                player = MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    setDataSource(this@AlarmService, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                    isLooping = true
                    setWakeMode(this@AlarmService, PowerManager.PARTIAL_WAKE_LOCK)
                    prepare(); start()
                }
            } catch (_: Exception) { AlarmEngine(this).event("audio_failed_visible_dismiss_available") }
        }
        // Experimental safety limit, not production wake-alarm behavior.
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ AlarmEngine(this).dismiss() }, 120_000)
        handler.postDelayed(accessWatch, 1_000)
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        player?.release(); player = null
        super.onDestroy()
    }
    companion object {
        fun notification(context: Context): Notification {
            val show = PendingIntent.getActivity(context, 201, Intent(context, AlarmActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val dismiss = PendingIntent.getBroadcast(context, 202, Intent(context, AlarmReceiver::class.java).setAction("dismiss"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            return Notification.Builder(context, "bimbi_alarm")
                .setSmallIcon(R.drawable.ic_stat_bimbi).setColor(context.getColor(R.color.bimbi_lilac_accent)).setContentTitle("Bimbi wake alarm")
                .setContentText("Dismiss is always available. Test audio stops after 2 minutes.")
                .setCategory(Notification.CATEGORY_ALARM).setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(true).setContentIntent(show).setFullScreenIntent(show, true)
                .addAction(Notification.Action.Builder(null, "Dismiss alarm", dismiss).build()).build()
        }
        fun postFallback(context: Context) {
            AlarmEngine.channels(context)
            context.getSystemService(NotificationManager::class.java).notify(200, notification(context))
        }
    }
}
