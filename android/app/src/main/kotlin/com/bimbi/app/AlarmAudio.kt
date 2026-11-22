package com.bimbi.app

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.LoudnessEnhancer
import android.os.Handler
import android.os.Looper
import android.os.PowerManager

internal class AlarmPlayback(val player: MediaPlayer, private val enhancer: LoudnessEnhancer?) {
    val boosted get() = enhancer != null

    fun release() {
        try {
            player.release()
        } finally {
            runCatching { enhancer?.release() }
        }
    }
}

internal object AlarmAudio {
    val boostAvailable: Boolean by lazy {
        runCatching {
            AudioEffect.queryEffects()?.any { it.type == AudioEffect.EFFECT_TYPE_LOUDNESS_ENHANCER } == true
        }.getOrDefault(false)
    }

    fun prepare(context: Context, sound: AlarmSound, looping: Boolean): AlarmPlayback {
        if (sound.tone == AlarmTone.SYSTEM) {
            // The user's default URI can become unavailable after a system update or restore.
            runCatching { create(context, sound, looping, AlarmTone.SYSTEM) }
                .getOrNull()?.let { return it }
            return create(context, sound, looping, AlarmTone.DAWN_CHIME)
        }
        return create(context, sound, looping, sound.tone)
    }

    private fun create(
        context: Context,
        sound: AlarmSound,
        looping: Boolean,
        tone: AlarmTone,
    ): AlarmPlayback {
        val player = MediaPlayer()
        try {
            player.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            when (tone) {
                AlarmTone.SYSTEM -> player.setDataSource(context, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                else -> context.resources.openRawResourceFd(resource(tone)).use { clip ->
                    player.setDataSource(clip.fileDescriptor, clip.startOffset, clip.length)
                }
            }
            player.isLooping = looping
            if (looping) player.setWakeMode(context, PowerManager.PARTIAL_WAKE_LOCK)
            player.prepare()
            player.setVolume(sound.gain, sound.gain)
            val enhancer = if (sound.intensity.needsBoost) {
                enableBoost(player.audioSessionId, sound.intensity.boostMillibels)
            } else null
            return AlarmPlayback(player, enhancer)
        } catch (failure: Exception) {
            player.release()
            throw failure
        }
    }

    private fun enableBoost(sessionId: Int, millibels: Int): LoudnessEnhancer? {
        if (!boostAvailable || sessionId <= 0) return null
        val enhancer = runCatching { LoudnessEnhancer(sessionId) }.getOrNull() ?: return null
        val enabled = runCatching {
            enhancer.setTargetGain(millibels)
            enhancer.setEnabled(true) == AudioEffect.SUCCESS
        }.getOrDefault(false)
        if (enabled) return enhancer
        runCatching { enhancer.release() }
        return null
    }

    private fun resource(tone: AlarmTone) = when (tone) {
        AlarmTone.DAWN_CHIME -> R.raw.alarm_dawn_chime
        AlarmTone.SOFT_BELLS -> R.raw.alarm_soft_bells
        AlarmTone.MORNING_PULSE -> R.raw.alarm_morning_pulse
        AlarmTone.BRIGHT_SIGNAL -> R.raw.alarm_bright_signal
        AlarmTone.SYSTEM -> error("System alarm has no bundled sound")
    }
}

/** A short sample, owned by the editor and always subordinate to an active alarm. */
internal object AlarmPreview {
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable(::stop)
    private var playback: AlarmPlayback? = null

    fun play(context: Context, sound: AlarmSound): Boolean {
        stop()
        val sample = AlarmAudio.prepare(context.applicationContext, sound, looping = false)
        playback = sample
        sample.player.setOnCompletionListener { if (playback === sample) stop() }
        sample.player.setOnErrorListener { _, _, _ ->
            if (playback === sample) stop()
            true
        }
        try {
            sample.player.start()
            handler.postDelayed(timeout, 3_000)
            return !sound.intensity.needsBoost || sample.boosted
        } catch (failure: Exception) {
            stop()
            throw failure
        }
    }

    fun stop() {
        handler.removeCallbacks(timeout)
        playback?.release()
        playback = null
    }
}
