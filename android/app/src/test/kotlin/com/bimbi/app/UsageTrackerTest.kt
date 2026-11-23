package com.bimbi.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UsageTrackerTest {
    private val min = 60_000L

    @Test
    fun movingBetweenScreensOfOneAppIsOneStretch() {
        val t = UsageTracker(0)
        t.resumed("video", "Main", 0)
        t.resumed("video", "Player", 5 * min) // new screen resumes before the old one pauses
        t.paused("video", "Main", 5 * min + 200)
        t.paused("video", "Player", 20 * min)
        assertEquals(20 * min, t.usage(30 * min)["video"])
        assertNull(t.foreground())
    }

    @Test
    fun anAppOpenBeforeCountingStartsIsCountedFromTheStart() {
        val t = UsageTracker(100 * min)
        t.paused("chat", "Main", 103 * min)
        t.paused("chat", "Main", 104 * min) // a duplicate pause adds nothing
        assertEquals(3 * min, t.usage(110 * min)["chat"])
    }

    @Test
    fun aMissingPauseKeepsCountingUntilNowAndStaysForeground() {
        val t = UsageTracker(0)
        t.resumed("game", "Main", 2 * min)
        assertEquals("game", t.foreground())
        assertEquals(8 * min, t.usage(10 * min)["game"])
    }

    @Test
    fun aNewDayResetsTotalsButKeepsTheOpenAppRunning() {
        val t = UsageTracker(0)
        t.resumed("game", "Main", 10 * min)
        t.rollOver(60 * min)
        assertEquals(5 * min, t.usage(65 * min)["game"])
        t.paused("game", "Main", 70 * min)
        assertEquals(10 * min, t.usage(80 * min)["game"])
    }

    @Test
    fun focusCoversChosenAppsUntilTheEndTimeOnly() {
        val rules = GuardRules(focusApps = setOf("video"), focusUntil = 30 * min)
        val none = { _: String -> false }
        assertTrue(shieldFor("video", rules, emptyMap(), 29 * min, none) is Shield.Focus)
        assertNull(shieldFor("video", rules, emptyMap(), 30 * min, none))
        assertNull(shieldFor("mail", rules, emptyMap(), 10 * min, none))
        assertTrue(rules.hasWork(10 * min))
        assertTrue(!rules.hasWork(31 * min))
    }

    @Test
    fun aDailyLimitCoversTheAppOnceItIsUsedUp() {
        val rules = GuardRules(limits = mapOf("video" to 30))
        val none = { _: String -> false }
        assertNull(shieldFor("video", rules, mapOf("video" to 29 * min), 0, none))
        val shield = shieldFor("video", rules, mapOf("video" to 30 * min), 0, none)
        assertEquals(Shield.Limit(30 * min, 30), shield)
        assertTrue(rules.hasWork(Long.MAX_VALUE))
    }

    @Test
    fun exemptAppsAreNeverCovered() {
        val rules = GuardRules(focusApps = setOf("settings"), limits = mapOf("settings" to 0), focusUntil = 99 * min)
        assertNull(shieldFor("settings", rules, mapOf("settings" to 99 * min), 1, { it == "settings" }))
        assertNull(shieldFor(null, rules, emptyMap(), 1, { false }))
    }
}
