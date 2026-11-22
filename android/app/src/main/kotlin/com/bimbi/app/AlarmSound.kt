package com.bimbi.app

internal enum class AlarmTone(val wire: String, val title: String) {
    SYSTEM("system", "Android default"),
    DAWN_CHIME("dawn_chime", "Dawn Chime"),
    SOFT_BELLS("soft_bells", "Soft Bells"),
    MORNING_PULSE("morning_pulse", "Morning Pulse"),
    BRIGHT_SIGNAL("bright_signal", "Bright Signal");

    companion object {
        fun parse(value: String?) = entries.firstOrNull { it.wire == value } ?: SYSTEM
    }
}

internal enum class AlarmIntensity(
    val wire: String,
    val title: String,
    val volumeScale: Float = 1f,
    val boostMillibels: Int = 0,
) {
    SOFTEST("softest", "Softest", volumeScale = 0.6f),
    NORMAL("normal", "Normal"),
    NOISY("noisy", "Noisy", boostMillibels = 600),
    HEAVY("heavy", "Heavy", boostMillibels = 900),
    JACKHAMMER("jackhammer", "Jackhammer", boostMillibels = 1200);

    val needsBoost get() = boostMillibels > 0

    companion object {
        fun parse(value: String?, legacyBoost: Boolean = false) =
            entries.firstOrNull { it.wire == value } ?: if (legacyBoost) NOISY else NORMAL
    }
}

internal data class AlarmSound(
    val tone: AlarmTone = AlarmTone.SYSTEM,
    val volume: Int = 100,
    val intensity: AlarmIntensity = AlarmIntensity.NORMAL,
) {
    val gain get() = volume / 100f * intensity.volumeScale

    companion object {
        fun from(tone: String?, volume: Int?, intensity: AlarmIntensity = AlarmIntensity.NORMAL) =
            AlarmSound(AlarmTone.parse(tone), (volume ?: 100).coerceIn(20, 100), intensity)
    }
}
