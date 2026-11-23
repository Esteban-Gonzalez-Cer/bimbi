package com.bimbi.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject

/**
 * Short sounds for Focus: a soft chime when a window ends and a sparkle when
 * the session ends. Scheduled with AlarmManager so they play even while
 * Bimbi is closed; cancelled whenever the session pauses or ends. Not an
 * alarm: no notification, and Android's sound and Do Not Disturb settings apply.
 */
internal object FocusChime {
    private const val ACTION = "com.bimbi.app.FOCUS_CHIME"
    private const val FIRST_CODE = 7100
    private const val MAX = FocusLimits.MAX_WINDOWS

    /** Replaces every pending chime with [windowEnds] plus [end]. */
    fun schedule(context: Context, windowEnds: List<Long>, end: Long?) {
        cancel(context)
        val now = System.currentTimeMillis()
        val chimes = buildList {
            windowEnds.filter { it > now && (end == null || it < end) }.sorted().take(MAX - 1)
                .forEach { add(it to "window") }
            end?.takeIf { it > now }?.let { add(it to "done") }
        }
        val manager = context.getSystemService(AlarmManager::class.java)
        val exact = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
        chimes.forEachIndexed { index, (at, kind) ->
            val pending = intent(context, index, kind, PendingIntent.FLAG_UPDATE_CURRENT) ?: return@forEachIndexed
            runCatching {
                if (exact) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
        val json = JSONArray(chimes.map { JSONObject().put("at", it.first).put("kind", it.second) })
        context.getSharedPreferences("bimbi_guard", Context.MODE_PRIVATE).edit().putString("chimes", json.toString()).apply()
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(AlarmManager::class.java)
        for (index in 0 until MAX) {
            intent(context, index, "window", PendingIntent.FLAG_NO_CREATE)?.let {
                manager.cancel(it)
                it.cancel()
            }
        }
        context.getSharedPreferences("bimbi_guard", Context.MODE_PRIVATE).edit().remove("chimes").apply()
    }

    /** Re-registers saved future chimes after a reboot or an app update. */
    fun restore(context: Context) {
        val stored = context.getSharedPreferences("bimbi_guard", Context.MODE_PRIVATE).getString("chimes", null) ?: return
        val items = runCatching { JSONArray(stored) }.getOrNull() ?: return
        val windows = mutableListOf<Long>()
        var end: Long? = null
        for (i in 0 until items.length()) {
            val item = items.getJSONObject(i)
            if (item.optString("kind") == "done") end = item.getLong("at") else windows += item.getLong("at")
        }
        schedule(context, windows, end)
    }

    private fun intent(context: Context, index: Int, kind: String, flag: Int): PendingIntent? =
        PendingIntent.getBroadcast(
            context, FIRST_CODE + index,
            Intent(context, FocusChimeReceiver::class.java).setAction(ACTION).putExtra("kind", kind),
            flag or PendingIntent.FLAG_IMMUTABLE,
        )

    /** Plays one chime and releases the player when it finishes. */
    fun play(context: Context, kind: String, done: () -> Unit = {}) {
        val raw = if (kind == "done") R.raw.focus_done else R.raw.focus_window
        val player = MediaPlayer()
        var finished = false
        val finish = {
            if (!finished) {
                finished = true
                runCatching { player.release() }
                done()
            }
        }
        runCatching {
            context.resources.openRawResourceFd(raw).use { player.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setOnCompletionListener { finish() }
            player.setOnErrorListener { _, _, _ -> finish(); true }
            player.prepare()
            player.start()
        }.onFailure { finish() }
        Handler(Looper.getMainLooper()).postDelayed({ finish() }, 4_000)
    }
}

internal object FocusLimits {
    const val MAX_WINDOWS = 6
}

class FocusChimeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val result = goAsync()
        FocusChime.play(context.applicationContext, intent.getStringExtra("kind") ?: "window") { result.finish() }
    }
}
