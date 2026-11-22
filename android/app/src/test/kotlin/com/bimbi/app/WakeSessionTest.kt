package com.bimbi.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class WakeSessionTest {
    private fun session(challenge: WakeChallenge, difficulty: WakeDifficulty = WakeDifficulty.NORMAL) =
        WakeSession(AlarmEpisode("session", "alarm", "Alarm", challenge, difficulty, 0), random = Random(42))

    @Test
    fun activityAtFourteenSecondsExtendsTheSameRoundAndDeadline() {
        val session = session(WakeChallenge.MATH)
        session.show(0)
        session.interact(14_000)
        session.tick(15_000)
        assertEquals(29_000L, session.deadline)
        assertEquals(0, session.attempt)
        assertEquals(1, session.round)
        session.tick(29_000)
        assertEquals(44_000L, session.deadline)
        assertEquals(1, session.attempt)
    }

    @Test
    fun expirationFromRoundThreeReturnsToTwoWhetherAudibleOrMuted() {
        for (muted in listOf(false, true)) {
            val session = session(WakeChallenge.MATH)
            repeat(2) { index ->
                val now = index * 100L
                session.show(now)
                session.answer(now, session.attempt, (session.board as WakeRound.Math).answer)
            }
            session.show(300)
            val expiredAttempt = session.attempt
            if (muted) session.toggleMute(300)
            val deadline = session.deadline!!
            session.tick(deadline)
            assertEquals(2, session.round)
            assertFalse(session.muted)
            assertNull(session.shownAt)
            session.show(deadline)
            session.answer(deadline, expiredAttempt, (session.board as WakeRound.Math).answer)
            assertEquals("Stale input cannot advance the restarted round", 2, session.round)
        }
    }

    @Test
    fun inactivityInRoundOneRestartsShakeProgressEvenWithSensorReadings() {
        val session = session(WakeChallenge.SHAKE)
        session.show(0)
        for (step in 1..10) session.shake(step * 600L, session.attempt)
        assertEquals(10, session.progress)
        assertEquals(15_000L, session.deadline)
        session.tick(15_000)
        assertEquals(1, session.round)
        assertEquals(0, session.progress)
    }

    @Test
    fun previewsAndActivityRecreationDoNotRearmTheDeadline() {
        val session = session(WakeChallenge.CUPS)
        session.show(100)
        session.toggleMute(200)
        session.show(8_000)
        assertEquals(100L, session.shownAt)
        assertEquals(15_200L, session.deadline)
        session.tick(15_200)
        assertFalse(session.muted)
        assertEquals(1, session.attempt)
    }

    @Test
    fun allChallengesCanFinishAtEveryDifficulty() {
        for (difficulty in WakeDifficulty.entries) {
            for (challenge in WakeChallenge.entries) {
                val session = session(challenge, difficulty)
                var now = 0L
                repeat(difficulty.rounds(challenge)) { round ->
                    assertEquals(round + 1, session.round)
                    session.show(now)
                    val attempt = session.attempt
                    when (val board = session.board) {
                        WakeRound.Shake -> repeat(difficulty.shakes) { session.shake(now + 10, attempt) }
                        is WakeRound.Math -> session.answer(now + 100, attempt, board.answer)
                        is WakeRound.Cups -> {
                            assertEquals(difficulty.cups, board.count)
                            assertEquals(difficulty.swapMillis - round * 60, board.swapMillis)
                            assertTrue(board.finalOrder.contains(board.ball))
                            session.choose(now + board.previewMillis, attempt, board.ball)
                        }
                        is WakeRound.Pattern -> {
                            assertEquals(difficulty.side, board.side)
                            assertEquals(difficulty.steps, board.cells.size)
                            for (cell in board.cells) session.choose(now + board.previewMillis, attempt, cell)
                        }
                        is WakeRound.Memory -> {
                            assertEquals(difficulty.pairs * 2, board.faces.size)
                            val pairs = board.faces.indices.groupBy { board.faces[it] }
                            for (pair in pairs.values) {
                                assertEquals(2, pair.size)
                                for (cell in pair) session.choose(now + WakeSession.MEMORY_PREVIEW_MS, attempt, cell)
                            }
                        }
                    }
                    now += 10_000
                }
                assertTrue("Finished: $challenge, $difficulty", session.completed)
            }
        }
    }

    @Test
    fun aWrongCupRetriesAtTheSameSpeedAndAWrongPatternReplaysInOrder() {
        val cups = session(WakeChallenge.CUPS)
        cups.show(0)
        val board = cups.board as WakeRound.Cups
        cups.choose(board.previewMillis, cups.attempt, (board.ball + 1) % board.count)
        assertEquals(board.ball, cups.wrongCup)
        cups.tick(board.previewMillis + 850)
        assertEquals(1, cups.round)
        assertEquals(board.swapMillis, (cups.board as WakeRound.Cups).swapMillis)
        assertNull(cups.wrongCup)

        val pattern = session(WakeChallenge.PATTERN)
        pattern.show(0)
        val cells = pattern.board as WakeRound.Pattern
        pattern.choose(cells.previewMillis, pattern.attempt, cells.cells[1])
        assertEquals(1, pattern.round)
        assertEquals(0, pattern.progress)
        assertEquals(cells, pattern.board)
    }
}
