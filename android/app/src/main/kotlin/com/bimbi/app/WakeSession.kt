package com.bimbi.app

import kotlin.math.abs
import kotlin.random.Random

internal enum class WakeChallenge(val wire: String, val title: String) {
    SHAKE("shake", "Shake"), MATH("math", "Math"), CUPS("ballMonte", "Ball Monte"),
    PATTERN("pattern", "Follow the pattern"), MEMORY("memory", "Memorama");

    companion object {
        fun parse(value: String?) = entries.firstOrNull { it.wire == value }
    }
}

internal enum class WakeDifficulty(
    val wire: String,
    val shakes: Int,
    val sums: Int,
    val cups: Int,
    val cupRounds: Int,
    val swapMillis: Long,
    val side: Int,
    val steps: Int,
    val pairs: Int,
) {
    EASY("easy", 15, 2, 3, 3, 710, 3, 3, 3),
    NORMAL("normal", 30, 3, 5, 3, 620, 4, 4, 4),
    DIFFICULT("difficult", 40, 4, 5, 5, 540, 5, 6, 6),
    EXTREME("extreme", 50, 5, 6, 5, 440, 6, 8, 8);

    fun rounds(challenge: WakeChallenge) = when (challenge) {
        WakeChallenge.SHAKE -> 1
        WakeChallenge.MATH -> sums
        WakeChallenge.CUPS -> cupRounds
        WakeChallenge.PATTERN -> 3
        WakeChallenge.MEMORY -> 2
    }

    companion object {
        fun parse(value: String?) = entries.firstOrNull { it.wire == value }
    }
}

internal sealed interface WakeRound {
    data object Shake : WakeRound
    data class Math(val expression: String, val answer: Int) : WakeRound
    data class Cups(
        val count: Int,
        val ball: Int,
        val swaps: List<Pair<Int, Int>>,
        val swapMillis: Long,
    ) : WakeRound {
        val previewMillis get() = 950 + swaps.size * swapMillis
        val finalOrder get() = orderAfter(swaps.size)

        fun orderAfter(count: Int): List<Int> = MutableList(this.count) { it }.apply {
            for ((a, b) in swaps.take(count)) {
                val first = this[a]
                this[a] = this[b]
                this[b] = first
            }
        }
    }
    data class Pattern(val side: Int, val cells: List<Int>) : WakeRound {
        val previewMillis get() = 650L + cells.size * 600L
        fun highlighted(elapsed: Long): Int? {
            val time = elapsed - 450
            if (time < 0 || time % 600 >= 425) return null
            return cells.getOrNull((time / 600).toInt())
        }
    }
    data class Memory(val faces: List<Int>) : WakeRound
}

internal class WakeSession(
    val episode: AlarmEpisode,
    challenge: WakeChallenge = episode.challenge,
    private val random: Random = Random.Default,
) {
    var challenge = challenge
        private set
    val difficulty get() = episode.difficulty
    val totalRounds get() = difficulty.rounds(challenge)
    var round = 1
        private set
    var attempt = 0
        private set
    var board: WakeRound = newBoard()
        private set
    var deadline: Long? = null
        private set
    var shownAt: Long? = null
        private set
    var muted = false
        private set
    var completed = false
        private set
    var feedback = ""
        private set
    var progress = 0
        private set
    var matched = emptySet<Int>()
        private set
    var exposed = emptyList<Int>()
        private set
    private var mismatchUntil = 0L
    var wrongCup: Int? = null
        private set
    private var wrongCupUntil = 0L

    fun show(now: Long) {
        if (completed) return
        tick(now)
        if (deadline == null) deadline = now + ACTIVE_WINDOW_MS
        if (shownAt == null) shownAt = now
    }

    fun interact(now: Long) {
        tick(now)
        if (!completed && deadline != null) deadline = now + ACTIVE_WINDOW_MS
    }

    fun toggleMute(now: Long) {
        if (completed) return
        interact(now)
        muted = !muted
    }

    fun tick(now: Long) {
        if (completed) return
        val expires = deadline
        if (expires != null && now >= expires) {
            val windows = (now - expires) / ACTIVE_WINDOW_MS + 1
            round = maxOf(1, round - minOf(windows, round.toLong()).toInt())
            muted = false
            deadline = expires + windows * ACTIVE_WINDOW_MS
            reset("Time ran out. Round $round restarted.")
        }
        if (mismatchUntil != 0L && now >= mismatchUntil) {
            exposed = emptyList()
            mismatchUntil = 0L
        }
        if (wrongCupUntil != 0L && now >= wrongCupUntil) reset()
    }

    fun fallbackToMath() {
        if (challenge == WakeChallenge.MATH) return
        challenge = WakeChallenge.MATH
        round = 1
        reset("Motion is unavailable. Solve the math challenge.")
    }

    fun shake(now: Long, expected: Int) {
        tick(now)
        if (!ready(expected) || board !is WakeRound.Shake) return
        progress++
        if (progress >= difficulty.shakes) advance()
    }

    fun answer(now: Long, expected: Int, value: Int?) {
        interact(now)
        val question = board as? WakeRound.Math ?: return
        if (!ready(expected)) return
        if (value == question.answer) advance() else feedback = "Try that answer again."
    }

    fun choose(now: Long, expected: Int, index: Int) {
        interact(now)
        if (!ready(expected)) return
        val elapsed = now - (shownAt ?: now)
        when (val puzzle = board) {
            is WakeRound.Cups -> if (elapsed >= puzzle.previewMillis && wrongCup == null) {
                if (index == puzzle.ball) advance() else {
                    wrongCup = puzzle.ball
                    wrongCupUntil = now + 850
                    feedback = "The ball was here. Try this round again."
                }
            }
            is WakeRound.Pattern -> if (elapsed >= puzzle.previewMillis) {
                if (index == puzzle.cells[progress]) {
                    progress++
                    if (progress == puzzle.cells.size) advance()
                } else {
                    reset("Watch the sequence again.", sameBoard = true)
                }
            }
            is WakeRound.Memory -> if (elapsed >= MEMORY_PREVIEW_MS && index in puzzle.faces.indices &&
                index !in matched && index !in exposed && exposed.size < 2
            ) {
                exposed = exposed + index
                if (exposed.size == 2) {
                    if (puzzle.faces[exposed.first()] == puzzle.faces[index]) {
                        matched = matched + exposed
                        exposed = emptyList()
                        if (matched.size == puzzle.faces.size) advance()
                    } else {
                        mismatchUntil = now + 750
                    }
                }
            }
            else -> Unit
        }
    }

    private fun ready(expected: Int) = !completed && shownAt != null && expected == attempt

    private fun advance() {
        if (round == totalRounds) completed = true else {
            round++
            reset()
        }
    }

    private fun reset(message: String = "", sameBoard: Boolean = false) {
        attempt++
        shownAt = null
        progress = 0
        feedback = message
        exposed = emptyList()
        matched = emptySet()
        mismatchUntil = 0L
        wrongCup = null
        wrongCupUntil = 0L
        if (!sameBoard) board = newBoard()
    }

    private fun newBoard(): WakeRound = when (challenge) {
        WakeChallenge.SHAKE -> WakeRound.Shake
        WakeChallenge.MATH -> {
            val multiply = difficulty.ordinal >= WakeDifficulty.DIFFICULT.ordinal && round % 2 == 0
            val subtract = difficulty != WakeDifficulty.EASY && round % 2 == 1
            val largest = when {
                multiply -> if (difficulty == WakeDifficulty.EXTREME) 12 else 9
                difficulty == WakeDifficulty.EXTREME -> 75
                difficulty == WakeDifficulty.DIFFICULT -> 38
                difficulty == WakeDifficulty.NORMAL -> 22
                else -> 9
            }
            val a = random.nextInt(2, largest + 1)
            val b = random.nextInt(2, largest + 1)
            when {
                multiply -> WakeRound.Math("$a × $b", a * b)
                subtract -> WakeRound.Math("${maxOf(a, b)} − ${minOf(a, b)}", abs(a - b))
                else -> WakeRound.Math("$a + $b", a + b)
            }
        }
        WakeChallenge.CUPS -> {
            val ball = random.nextInt(difficulty.cups)
            val swaps = List(5) { index ->
                val left = if (index == 0) ball else random.nextInt(difficulty.cups)
                val other = (left + random.nextInt(1, difficulty.cups)) % difficulty.cups
                left to other
            }
            WakeRound.Cups(difficulty.cups, ball, swaps, difficulty.swapMillis - (round - 1) * 60)
        }
        WakeChallenge.PATTERN -> WakeRound.Pattern(
            difficulty.side,
            (0 until difficulty.side * difficulty.side).shuffled(random).take(difficulty.steps),
        )
        WakeChallenge.MEMORY -> WakeRound.Memory(
            (0 until difficulty.pairs).flatMap { listOf(it, it) }.shuffled(random),
        )
    }

    companion object {
        const val MEMORY_PREVIEW_MS = 2_500L
    }
}
