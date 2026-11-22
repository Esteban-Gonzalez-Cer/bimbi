package com.bimbi.app

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.util.UUID

internal const val TEST_ALARM_ID = "phase1-alarm"
internal const val ACTIVE_WINDOW_MS = 15_000L
internal const val SNOOZE_MS = 5 * 60_000L
internal const val MAX_SNOOZES = 2

internal data class LocalAlarm(
    val id: String,
    val label: String,
    val hour: Int,
    val minute: Int,
    val days: Set<Int>,
    val challenge: WakeChallenge,
    val difficulty: WakeDifficulty,
    val enabled: Boolean = true,
    val onceDay: LocalDate? = null,
    val lastFiredDay: LocalDate? = null,
    val next: AlarmTime? = null,
    val status: AlarmStatus = AlarmStatus.OFF,
    val sound: AlarmSound = AlarmSound(),
) {
    val time: LocalTime get() = LocalTime.of(hour, minute)

    /** java.time advances gaps by their duration and takes the earlier offset at overlaps. */
    fun firstAfter(now: Long, zone: ZoneId): AlarmTime? {
        if (!enabled) return null
        val today = Instant.ofEpochMilli(now).atZone(zone).toLocalDate()
        if (days.isEmpty()) {
            onceDay?.let { return on(it, zone).takeIf { target -> target.at > now } }
            val candidate = on(today, zone)
            return if (candidate.at > now) candidate else on(today.plusDays(1), zone)
        }
        return (0L..7L)
            .asSequence()
            .map(today::plusDays)
            .filter { it.dayOfWeek.value - 1 in days && it != lastFiredDay }
            .map { on(it, zone) }
            .firstOrNull { it.at > now }
    }

    private fun on(date: LocalDate, zone: ZoneId) =
        AlarmTime(date.atTime(time).atZone(zone).toInstant().toEpochMilli(), date)

    fun startOccurrence(occurrence: AlarmTime, deliveredAt: Long) = AlarmEpisode(
        id = UUID.randomUUID().toString(),
        alarmId = id,
        label = label,
        challenge = challenge,
        difficulty = difficulty,
        arrivedAt = deliveredAt,
        scheduledAt = occurrence.at,
        sound = sound,
    )
}

internal data class AlarmTime(val at: Long, val day: LocalDate)

internal enum class AlarmStatus(val wire: String) {
    OFF("off"), ARMED("armed"), BLOCKED_EXACT("exact"), BLOCKED_NOTIFICATIONS("notifications"),
    ERROR("error"), FINISHED("finished"), MISSED("missed")
}

internal data class AlarmEpisode(
    val id: String,
    val alarmId: String,
    val label: String,
    val challenge: WakeChallenge,
    val difficulty: WakeDifficulty,
    val arrivedAt: Long,
    val snoozes: Int = 0,
    val snooze: SnoozeTime? = null,
    val scheduledAt: Long = arrivedAt,
    val sound: AlarmSound = AlarmSound(),
) {
    val isTest get() = alarmId == TEST_ALARM_ID
    val snoozesLeft get() = MAX_SNOOZES - snoozes

    fun postpone(at: Long, elapsed: Long, boot: Int): AlarmEpisode? {
        if (isTest || snooze != null || snoozesLeft <= 0) return null
        return copy(snoozes = snoozes + 1, snooze = SnoozeTime(at + SNOOZE_MS, elapsed + SNOOZE_MS, boot))
    }

    fun resumeFromSnooze(deliveredAt: Long) = copy(arrivedAt = deliveredAt, snooze = null)
}

internal data class SnoozeTime(val at: Long, val elapsed: Long, val boot: Int) {
    fun resolve(now: Long, nowElapsed: Long, currentBoot: Int): Long =
        if (boot >= 0 && boot == currentBoot) now + (elapsed - nowElapsed) else at
}

internal data class TestAlarm(val at: Long, val intervalSeconds: Long)

internal data class AlarmBook(
    val alarms: List<LocalAlarm> = emptyList(),
    val episodes: List<AlarmEpisode> = emptyList(),
    val test: TestAlarm? = null,
) {
    val active: AlarmEpisode?
        get() = episodes.filter { it.snooze == null }
            .minWithOrNull(compareBy(AlarmEpisode::isTest, AlarmEpisode::arrivedAt))

    fun put(alarm: LocalAlarm) = copy(alarms = alarms.filterNot { it.id == alarm.id } + alarm)
    fun put(episode: AlarmEpisode) = copy(episodes = episodes.map { if (it.id == episode.id) episode else it })
}
