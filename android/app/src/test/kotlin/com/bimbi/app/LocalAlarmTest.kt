package com.bimbi.app

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalAlarmTest {
    private fun ms(value: String) = Instant.parse(value).toEpochMilli()

    private fun alarm(days: Set<Int> = emptySet(), hour: Int = 7, minute: Int = 0) = LocalAlarm(
        id = "alarm",
        label = "Alarm",
        hour = hour, minute = minute, days = days,
        challenge = WakeChallenge.CUPS, difficulty = WakeDifficulty.EXTREME,
    )

    @Test
    fun onceSchedulesTheNextFutureTimeAndAnExpiredDatedAlarmStaysExpired() {
        val utc = ZoneId.of("UTC")
        val now = ms("2026-11-21T08:30:00Z")
        assertEquals(ms("2026-11-22T07:00:00Z"), alarm().firstAfter(now, utc)?.at)
        assertNull(alarm().copy(onceDay = LocalDate.of(2026, 11, 21)).firstAfter(now, utc))
        assertNull(alarm().copy(enabled = false).firstAfter(now, utc))
    }

    @Test
    fun weekdaysAndAFiredDateStayStableDuringClockChanges() {
        val utc = ZoneId.of("UTC")
        val monday = LocalDate.of(2026, 11, 23)
        val weekdays = alarm(setOf(0, 1, 2, 3, 4))
        assertEquals(monday, weekdays.firstAfter(ms("2026-11-21T08:30:00Z"), utc)?.day)
        assertEquals(monday.plusDays(1), weekdays.copy(lastFiredDay = monday)
            .firstAfter(ms("2026-11-23T05:30:00Z"), utc)?.day)
    }

    @Test
    fun recurrenceShiftsThroughAGapAndUsesTheFirstTimeInAnOverlap() {
        val berlin = ZoneId.of("Europe/Berlin")
        val sunday = alarm(setOf(6), hour = 2, minute = 30)
        assertEquals(ms("2026-03-29T01:30:00Z"), sunday.firstAfter(ms("2026-03-29T00:00:00Z"), berlin)?.at)
        assertEquals(ms("2026-10-25T00:30:00Z"), sunday.firstAfter(ms("2026-10-24T21:00:00Z"), berlin)?.at)
    }

    @Test
    fun eachOccurrenceHasTwoFiveMinuteSnoozesAndKeepsItsChallenge() {
        val first = AlarmEpisode("one", "alarm", "Alarm", WakeChallenge.CUPS, WakeDifficulty.DIFFICULT, 20)
        val second = first.copy(id = "two", arrivedAt = 40)
        val postponed = first.postpone(at = 100_000, elapsed = 50_000, boot = 3)!!
        assertEquals(400_000L, postponed.snooze?.at)
        assertEquals(350_000L, postponed.snooze?.elapsed)
        assertEquals(1, postponed.snoozesLeft)
        assertEquals(WakeChallenge.CUPS, postponed.challenge)
        assertEquals(WakeDifficulty.DIFFICULT, postponed.difficulty)
        assertEquals(550_000L, postponed.snooze?.resolve(now = 300_000, nowElapsed = 100_000, currentBoot = 3))
        assertEquals(400_000L, postponed.snooze?.resolve(now = 300_000, nowElapsed = 100_000, currentBoot = 4))
        assertNull(postponed.postpone(at = 200_000, elapsed = 150_000, boot = 3))
        val twice = postponed.resumeFromSnooze(400_000).postpone(at = 400_000, elapsed = 350_000, boot = 3)!!
        assertEquals(0, twice.snoozesLeft)
        assertNull(twice.resumeFromSnooze(700_000).postpone(at = 700_000, elapsed = 650_000, boot = 3))
        assertEquals(2, second.snoozesLeft)
        assertEquals(first, AlarmBook(episodes = listOf(second, first)).active)
        assertEquals(second, AlarmBook(episodes = listOf(second, postponed)).active)
        assertFalse(second.isTest)
    }

    @Test
    fun mondayAndTuesdayAtSevenStartWithTheirOwnSnoozesAndSavedSound() {
        val utc = ZoneId.of("UTC")
        val sound = AlarmSound(AlarmTone.SOFT_BELLS, 45, AlarmIntensity.HEAVY)
        val weekdays = alarm(setOf(0, 1)).copy(sound = sound)
        val monday = weekdays.firstAfter(ms("2026-11-23T06:59:00Z"), utc)!!
        val mondayEpisode = weekdays.startOccurrence(monday, monday.at)
        val firstSnooze = mondayEpisode.postpone(monday.at, 0, boot = 1)!!
        val otherAlarm = weekdays.copy(id = "other-alarm", sound = AlarmSound(AlarmTone.BRIGHT_SIGNAL, 90))
        val otherEpisode = otherAlarm.startOccurrence(monday, monday.at + 1)
        assertEquals(otherEpisode, AlarmBook(episodes = listOf(firstSnooze, otherEpisode)).active)
        assertEquals(2, otherEpisode.snoozesLeft)

        val firstReturn = firstSnooze.resumeFromSnooze(monday.at + SNOOZE_MS)
        assertEquals(1, firstReturn.snoozesLeft)
        val secondSnooze = firstReturn.postpone(firstReturn.arrivedAt, SNOOZE_MS, boot = 1)!!
        val secondReturn = secondSnooze.resumeFromSnooze(monday.at + 2 * SNOOZE_MS)
        assertEquals(mondayEpisode.id, secondReturn.id)
        assertEquals(monday.at, secondReturn.scheduledAt)
        assertEquals(sound, secondReturn.sound)
        assertEquals(0, secondReturn.snoozesLeft)

        val tuesday = weekdays.copy(lastFiredDay = monday.day).firstAfter(secondReturn.arrivedAt, utc)!!
        assertEquals(ms("2026-11-24T07:00:00Z"), tuesday.at)
        val tuesdayEpisode = weekdays.startOccurrence(tuesday, tuesday.at)
        assertEquals(mondayEpisode.alarmId, tuesdayEpisode.alarmId)
        assertFalse(mondayEpisode.id == tuesdayEpisode.id)
        assertEquals(2, tuesdayEpisode.snoozesLeft)
        assertEquals(sound, tuesdayEpisode.sound)
    }

    @Test
    fun alarmSoundUsesSafeDefaultsAndScalesTheAndroidAlarmStream() {
        assertEquals(AlarmSound(), AlarmSound.from(null, null))
        assertEquals(AlarmSound(AlarmTone.SYSTEM, 20), AlarmSound.from("unknown", -10))
        assertEquals(1.0f, AlarmSound.from("dawn_chime", 140).gain, 0.001f)
        assertEquals(0.45f, AlarmSound.from("morning_pulse", 45).gain, 0.001f)
        assertEquals(0.6f, AlarmSound(intensity = AlarmIntensity.SOFTEST).gain, 0.001f)
        assertEquals(AlarmIntensity.NOISY, AlarmIntensity.parse(null, legacyBoost = true))
        assertEquals(AlarmIntensity.NORMAL, AlarmIntensity.parse("normal", legacyBoost = true))
        assertTrue(AlarmIntensity.NOISY.boostMillibels < AlarmIntensity.HEAVY.boostMillibels)
        assertTrue(AlarmIntensity.HEAVY.boostMillibels < AlarmIntensity.JACKHAMMER.boostMillibels)
    }
}
