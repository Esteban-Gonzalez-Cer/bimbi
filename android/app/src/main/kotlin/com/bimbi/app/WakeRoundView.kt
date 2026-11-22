package com.bimbi.app

import android.animation.ValueAnimator
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.sin

internal class WakeRoundView(
    private val activity: AlarmActivity,
    private val puzzle: WakeRound,
    private val content: LinearLayout,
    private val choose: (Int) -> Unit,
    private val answer: (Int?) -> Unit,
) {
    private val cells = mutableListOf<Button>()
    private val cups = mutableListOf<CupShape>()
    private val info = activity.text(16f)
    private var previousCupStage = -2

    init {
        content.addView(info, LinearLayout.LayoutParams(-1, -2))
        when (puzzle) {
            WakeRound.Shake -> Unit
            is WakeRound.Math -> math(puzzle)
            is WakeRound.Cups -> cups(puzzle)
            is WakeRound.Pattern -> grid(puzzle.side * puzzle.side, puzzle.side)
            is WakeRound.Memory -> grid(puzzle.faces.size, if (puzzle.faces.size == 6) 3 else 4)
        }
    }

    fun refresh(session: WakeSession, elapsed: Long) {
        when (puzzle) {
            WakeRound.Shake -> showText(info, "Gently shake your device\n${session.progress} of ${session.difficulty.shakes}")
            is WakeRound.Math -> Unit
            is WakeRound.Cups -> updateCups(puzzle, session.wrongCup, elapsed)
            is WakeRound.Pattern -> updatePattern(puzzle, session.progress, elapsed)
            is WakeRound.Memory -> updateMemory(puzzle, session.exposed, session.matched, elapsed)
        }
    }

    private fun math(puzzle: WakeRound.Math) {
        info.text = "Solve the operation"
        content.addView(activity.text(40f, heading = true).apply {
            text = puzzle.expression
            contentDescription = puzzle.expression.replace("×", "times").replace("−", "minus").replace("+", "plus")
        })
        val input = EditText(activity).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            imeOptions = EditorInfo.IME_ACTION_DONE
            filters = arrayOf(InputFilter.LengthFilter(3))
            textSize = 24f
            hint = "Answer"
            gravity = Gravity.CENTER
            setTextColor(activity.ink)
            setHintTextColor(activity.tint)
            setSelectAllOnFocus(true)
            backgroundTintList = ColorStateList.valueOf(activity.tint)
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                    activity.interaction()
                }
                override fun afterTextChanged(s: Editable?) = Unit
            })
            setOnEditorActionListener { _, actionId, _ ->
                if (actionId != EditorInfo.IME_ACTION_DONE) false else {
                    answer(text.toString().toIntOrNull())
                    true
                }
            }
        }
        content.addView(input, LinearLayout.LayoutParams(-1, -2).apply {
            marginStart = activity.dp(32)
            marginEnd = activity.dp(32)
        })
        content.addView(activity.button("Check answer") { answer(input.text.toString().toIntOrNull()) })
    }

    private fun grid(count: Int, columns: Int) {
        for (start in 0 until count step columns) {
            val row = LinearLayout(activity)
            for (index in start until minOf(start + columns, count)) {
                val button = activity.button("") { choose(index) }
                cells.add(button)
                row.addView(button, LinearLayout.LayoutParams(0, -2, 1f).apply {
                    marginStart = activity.dp(1)
                    marginEnd = activity.dp(1)
                    topMargin = activity.dp(2)
                })
            }
            content.addView(row, LinearLayout.LayoutParams(-1, -2))
        }
    }

    private fun cups(puzzle: WakeRound.Cups) {
        val row = LinearLayout(activity).apply {
            clipChildren = false
            clipToPadding = false
            setPadding(0, activity.dp(16), 0, activity.dp(12))
        }
        for (index in 0 until puzzle.count) {
            val shape = CupShape(activity.dp(1).toFloat(), activity.accent, activity.ink)
            val cup = activity.button("") { choose(index) }.apply { foreground = shape }
            cups.add(shape)
            cells.add(cup)
            row.addView(cup, LinearLayout.LayoutParams(0, activity.dp(68), 1f).apply {
                marginStart = activity.dp(1)
                marginEnd = activity.dp(1)
            })
        }
        content.addView(row, LinearLayout.LayoutParams(-1, -2))
    }

    private fun updateCups(puzzle: WakeRound.Cups, wrongCup: Int?, elapsed: Long) {
        val shuffleAt = (elapsed - 950).coerceAtLeast(0)
        val moves = (shuffleAt / puzzle.swapMillis).toInt().coerceAtMost(puzzle.swaps.size)
        val waiting = elapsed < 950
        val ready = elapsed >= puzzle.previewMillis
        val stage = if (waiting) -1 else moves
        val startPositions = puzzle.orderAfter(moves)
        val move = puzzle.swaps.getOrNull(moves)?.takeUnless { waiting || ready }
        val fraction = (shuffleAt % puzzle.swapMillis).toFloat() / puzzle.swapMillis
        val softMotion = !ValueAnimator.areAnimatorsEnabled()
        showText(info, when {
            waiting -> "Watch where the ball starts."
            !ready -> "Follow the ball’s cup."
            wrongCup != null -> "Watch for the next shuffle."
            else -> "Which cup is hiding the ball?"
        })
        for ((id, cup) in cells.withIndex()) {
            val position = startPositions.indexOf(id)
            val destination = if (move == null) position else when (position) {
                move.first -> move.second
                move.second -> move.first
                else -> position
            }
            val distance = cup.width + 2 * activity.dp(1)
            val travel = if (softMotion) 0f else (destination - position) * fraction
            cup.translationX = (position - id + travel) * distance
            val lift = if (destination == position || softMotion) 0f else sin(fraction * Math.PI).toFloat()
            cup.translationY = if (destination < position) lift * activity.dp(14) else -lift * activity.dp(10)
            cups[id].reveal = id == puzzle.ball && (waiting || wrongCup != null)
            if (previousCupStage != stage) {
                cup.contentDescription = if (cups[id].reveal) "Cup ${position + 1}, ball visible" else "Cup ${position + 1}"
            }
        }
        previousCupStage = stage
    }

    private fun updatePattern(puzzle: WakeRound.Pattern, progress: Int, elapsed: Long) {
        val preview = elapsed < puzzle.previewMillis
        val active = puzzle.highlighted(elapsed)
        showText(info, if (preview) "Watch the sequence." else "Repeat · $progress of ${puzzle.cells.size}")
        for ((index, cell) in cells.withIndex()) {
            val lit = if (preview) active == index else index in puzzle.cells.take(progress)
            paint(cell, lit)
            showText(cell, if (lit) "●" else "")
            describe(cell, "Row ${index / puzzle.side + 1}, column ${index % puzzle.side + 1}" +
                if (lit) ", highlighted" else "")
        }
    }

    private fun updateMemory(puzzle: WakeRound.Memory, exposed: List<Int>, matched: Set<Int>, elapsed: Long) {
        val preview = elapsed < WakeSession.MEMORY_PREVIEW_MS
        showText(info, if (preview) "Remember the card positions." else
            "Find the pairs · ${matched.size / 2} of ${puzzle.faces.size / 2}")
        for ((index, cell) in cells.withIndex()) {
            val face = puzzle.faces[index]
            val visible = preview || index in matched || index in exposed
            paint(cell, index in matched)
            showText(cell, if (visible) symbols[face] else "◆")
            describe(cell, "Card ${index + 1}, " + when {
                index in matched -> "${names[face]}, matched"
                visible -> names[face]
                else -> "face down"
            })
        }
    }

    private fun paint(button: Button, selected: Boolean) {
        if (button.isSelected == selected) return
        button.isSelected = selected
        activity.paintButton(button, selected)
    }

    private fun showText(view: TextView, value: String) {
        if (view.text.toString() != value) view.text = value
    }

    private fun describe(view: Button, value: String) {
        if (view.contentDescription?.toString() != value) view.contentDescription = value
    }

    companion object {
        private val symbols = listOf("★", "♥", "●", "▲", "☾", "✦", "♣", "■")
        private val names = listOf("star", "heart", "circle", "triangle", "moon", "sparkle", "clover", "square")
    }
}

private class CupShape(private val stroke: Float, private val lavender: Int, private val ink: Int) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val outline = Path()
    var reveal = false
        set(value) {
            if (field == value) return
            field = value
            invalidateSelf()
        }

    override fun draw(canvas: Canvas) {
        val center = bounds.exactCenterX()
        val width = bounds.width() * 0.31f
        val top = bounds.top + bounds.height() * 0.22f
        val bottom = bounds.top + bounds.height() * if (reveal) 0.56f else 0.75f
        outline.rewind()
        outline.moveTo(center - width * 0.64f, top)
        outline.lineTo(center + width * 0.64f, top)
        outline.lineTo(center + width, bottom)
        outline.lineTo(center - width, bottom)
        outline.close()
        paint.color = lavender
        paint.style = Paint.Style.FILL
        canvas.drawPath(outline, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = stroke
        paint.color = ink
        canvas.drawPath(outline, paint)
        if (reveal) {
            paint.style = Paint.Style.FILL
            canvas.drawCircle(center, bounds.top + bounds.height() * 0.76f, width * 0.3f, paint)
        }
    }

    override fun setAlpha(alpha: Int) { paint.alpha = alpha }
    override fun setColorFilter(colorFilter: ColorFilter?) { paint.colorFilter = colorFilter }
    @Deprecated("Drawable opacity is no longer consulted by Android")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
}
