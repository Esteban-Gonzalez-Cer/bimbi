package com.bimbi.app

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock

/** The challenge session and its clock live with the foreground audio, not the Activity. */
class AlarmService : Service() {
    private val engine by lazy { AlarmEngine(this) }
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var silentLock: PowerManager.WakeLock? = null
    private var polling = false
    private var testStart = 0L
    private var foreground = false
    private var playbackAttempted = false
    internal var session: WakeSession? = null
        private set
    internal var error: String = ""
        private set

    private val heartbeat = object : Runnable {
        override fun run() {
            polling = false
            refresh()
        }
    }

    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        current = this
        AlarmEngine.channels(this)
        refresh()
        return START_NOT_STICKY
    }

    internal fun refresh() {
        var active = engine.active()
        if (active == null || !engine.notificationsAllowed()) {
            if (active != null) engine.event("audio_interrupted_by_notification_permission")
            close()
            return
        }
        val now = SystemClock.elapsedRealtime()
        val previous = session
        if (previous != null && previous.episode.id == active.id) {
            when {
                previous.completed -> {
                    engine.complete(active.id)
                    active = engine.active()
                }
                active.isTest && now - testStart >= 120_000 -> {
                    engine.expireTest(active.id)
                    active = engine.active()
                }
            }
        }
        if (active == null) {
            close()
            return
        }

        if (session?.episode?.id != active.id) {
            val challenge = if (active.challenge == WakeChallenge.SHAKE &&
                getSystemService(SensorManager::class.java).getDefaultSensor(Sensor.TYPE_ACCELEROMETER) == null
            ) WakeChallenge.MATH else active.challenge
            session = WakeSession(active, challenge)
            error = ""
            testStart = now
            playbackAttempted = false
            val alert = notification(this)
            try {
                if (foreground) {
                    getSystemService(NotificationManager::class.java).notify(NOTIFICATION, alert)
                } else {
                    startForeground(NOTIFICATION, alert)
                    foreground = true
                }
            } catch (_: Exception) {
                engine.event("foreground_alert_unavailable")
                close()
                postFallback(this)
                return
            }
        }
        val state = checkNotNull(session)
        val wasMuted = state.muted
        state.tick(now)
        if (wasMuted && !state.muted) engine.event("inactivity_audio_resumed:round=${state.round}")
        synchronizeAudio(state)
        scheduleHeartbeat(state, now)
    }

    internal fun showRound(id: String) {
        val state = session?.takeIf { it.episode.id == id } ?: return
        if (state.shownAt != null) return
        refresh()
        if (session !== state) return
        val now = SystemClock.elapsedRealtime()
        state.show(now)
        scheduleHeartbeat(state, now)
    }

    internal fun interact(id: String) {
        val state = session?.takeIf { it.episode.id == id } ?: return
        state.interact(SystemClock.elapsedRealtime())
        if (state.muted) keepAwakeUntilDeadline(state) else synchronizeAudio(state)
        scheduleHeartbeat(state, SystemClock.elapsedRealtime())
    }

    internal fun mute(id: String) {
        val state = session?.takeIf { it.episode.id == id } ?: return
        state.toggleMute(SystemClock.elapsedRealtime())
        if (state.muted) {
            keepAwakeUntilDeadline(state)
            engine.event("audio_muted")
        } else {
            engine.event("audio_resumed_manually")
        }
        refresh()
    }

    internal fun postpone(id: String) {
        if (session?.episode?.id != id) return
        if (!engine.snooze(id)) {
            error = "Could not snooze. Check alarm access."
            return
        }
        releaseSilentLock()
        refresh()
    }

    private fun synchronizeAudio(state: WakeSession) {
        if (state.muted) {
            runCatching { if (player?.isPlaying == true) player?.pause() }
            return
        }
        releaseSilentLock()
        if (!playbackAttempted) {
            playbackAttempted = true
            if (player == null) startPlayer()
        }
        val activePlayer = player ?: return
        runCatching { if (!activePlayer.isPlaying) activePlayer.start() }.onFailure {
            engine.event("audio_failed_challenge_available")
            error = "Alarm audio unavailable. You can still finish the challenge."
            activePlayer.release()
            player = null
        }
    }

    private fun startPlayer() {
        val audio = MediaPlayer()
        try {
            val ringtone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            audio.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            audio.setDataSource(this, ringtone)
            audio.isLooping = true
            audio.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            audio.prepare()
            player = audio
        } catch (_: Exception) {
            audio.release()
            engine.event("audio_failed_challenge_available")
            error = "Alarm audio unavailable. You can still finish the challenge."
        }
    }

    // Keep the CPU awake for the bounded silent interval even if the screen turns off.
    private fun keepAwakeUntilDeadline(state: WakeSession) {
        val remaining = (state.deadline ?: return) - SystemClock.elapsedRealtime()
        if (remaining <= 0) return
        val lock = silentLock ?: getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "bimbi:wake-interaction")
            .apply { setReferenceCounted(false) }
            .also { silentLock = it }
        lock.acquire(remaining + 1_000)
    }

    private fun releaseSilentLock() {
        silentLock?.let { if (it.isHeld) it.release() }
    }

    private fun scheduleHeartbeat(state: WakeSession, now: Long) {
        if (polling) handler.removeCallbacks(heartbeat)
        val remaining = state.deadline?.minus(now) ?: 1_000L
        polling = true
        handler.postDelayed(heartbeat, remaining.coerceIn(1L, 1_000L))
    }

    private fun close() {
        session = null
        handler.removeCallbacks(heartbeat)
        polling = false
        releaseSilentLock()
        player?.release()
        player = null
        if (foreground) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            foreground = false
        } else {
            getSystemService(NotificationManager::class.java).cancel(NOTIFICATION)
        }
        if (current === this) current = null
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        releaseSilentLock()
        player?.release()
        if (current === this) current = null
        super.onDestroy()
    }

    companion object {
        const val NOTIFICATION = 200
        internal var current: AlarmService? = null
            private set

        internal fun start(context: Context) {
            try {
                context.startForegroundService(Intent(context, AlarmService::class.java))
            } catch (_: Exception) {
                AlarmEngine(context).event("audio_service_start_blocked")
                postFallback(context)
            }
        }

        private fun notification(context: Context): Notification {
            val show = PendingIntent.getActivity(
                context, 201,
                Intent(context, AlarmActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                ),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val notifications = Notification.Builder(context, AlarmEngine.CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_bimbi)
                .setColor(context.getColor(R.color.bimbi_lilac_accent))
                .setContentTitle("Bimbi wake alarm")
                .setContentText("Open your wake-up challenge.")
                .setCategory(Notification.CATEGORY_ALARM)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(show)
                .addAction(Notification.Action.Builder(null, "Open challenge", show).build())
            if (AlarmEngine(context).fullScreenAllowed()) notifications.setFullScreenIntent(show, true)
            return notifications.build()
        }

        private fun postFallback(context: Context) {
            val engine = AlarmEngine(context)
            if (engine.active() == null || !engine.notificationsAllowed()) return
            val manager = context.getSystemService(NotificationManager::class.java)
            runCatching { manager.notify(NOTIFICATION, notification(context)) }
        }
    }
}
