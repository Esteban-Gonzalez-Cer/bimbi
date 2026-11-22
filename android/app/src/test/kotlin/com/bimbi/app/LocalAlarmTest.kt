package com.bimbi.app

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
        val twice = postponed.copy(snooze = null).postpone(at = 400_000, elapsed = 350_000, boot = 3)!!
        assertEquals(0, twice.snoozesLeft)
        assertNull(twice.copy(snooze = null).postpone(at = 700_000, elapsed = 650_000, boot = 3))
        assertEquals(2, second.snoozesLeft)
        assertEquals(first, AlarmBook(episodes = listOf(second, first)).active)
        assertEquals(second, AlarmBook(episodes = listOf(second, postponed)).active)
        assertFalse(second.isTest)
    }
}
