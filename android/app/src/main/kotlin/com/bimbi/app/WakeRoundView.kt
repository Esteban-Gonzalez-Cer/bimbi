package com.bimbi.app

import android.animation.ValueAnimator
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
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
import kotlin.math.roundToInt
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
    private val cards = mutableListOf<MemoryCardArt>()
    private val info = activity.text(16f).apply {
        typeface = activity.strongFont
        minimumHeight = activity.dp(28)
    }
    private var shakeProgress: TextView? = null
    private var previousCupStage = -2
    private var tiles: SquareBoard? = null

    /**
     * Shrinks the board so the whole screen fits without scrolling, keeping 48dp touch targets.
     * Called after layout with the number of pixels that overflow the visible area.
     */
    fun fit(overflow: Int) {
        val board = tiles ?: return
        if (overflow <= 0 || board.side <= 0) return
        val target = maxOf(board.side - (overflow + board.rows - 1) / board.rows, activity.dp(MIN_TILE))
        if (target < board.side) {
            board.fitSide = target
            board.requestLayout()
        }
    }

    /** Lets the board grow again after the visible area changes. Returns true if it relaid out. */
    fun resetFit(): Boolean {
        val board = tiles ?: return false
        if (board.fitSide == Int.MAX_VALUE) return false
        board.fitSide = Int.MAX_VALUE
        board.requestLayout()
        return true
    }

    init {
        content.addView(info, LinearLayout.LayoutParams(-1, -2))
        when (puzzle) {
            WakeRound.Shake -> {
                info.text = "Gently shake your device"
                shakeProgress = activity.text(48f, heading = true).also { content.addView(it) }
            }
            is WakeRound.Math -> math(puzzle)
            is WakeRound.Cups -> cups(puzzle)
            is WakeRound.Pattern -> board(puzzle.side * puzzle.side, puzzle.side, maxSize = 72)
            is WakeRound.Memory -> memory(puzzle)
        }
    }

    fun refresh(session: WakeSession, elapsed: Long) {
        when (puzzle) {
            WakeRound.Shake -> shakeProgress?.let {
                showText(it, "${session.progress} of ${session.difficulty.shakes}")
            }
            is WakeRound.Math -> Unit
            is WakeRound.Cups -> updateCups(puzzle, session.wrongCup, elapsed)
            is WakeRound.Pattern -> updatePattern(puzzle, session.progress, elapsed)
            is WakeRound.Memory -> updateMemory(puzzle, session.exposed, session.matched, elapsed)
        }
    }

    private fun math(puzzle: WakeRound.Math) {
        info.text = "Solve the operation"
        content.addView(activity.text(48f, heading = true).apply {
            text = puzzle.expression
            contentDescription = puzzle.expression.replace("×", "times").replace("−", "minus").replace("+", "plus")
        }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = activity.dp(10) })
        val input = EditText(activity).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            imeOptions = EditorInfo.IME_ACTION_DONE
            filters = arrayOf(InputFilter.LengthFilter(3))
            textSize = 22f
            typeface = activity.strongFont
            minHeight = activity.dp(BUTTON_HEIGHT)
            hint = "Your answer"
            gravity = Gravity.CENTER
            includeFontPadding = false
            setPadding(activity.dp(12), 0, activity.dp(12), 0)
            setTextColor(activity.ink)
            setHintTextColor(activity.tint)
            setSelectAllOnFocus(true)
            background = GradientDrawable().apply {
                cornerRadius = activity.dp(16).toFloat()
                setColor(activity.raised)
                setStroke(activity.dp(2), activity.tint)
            }
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
        // Same width as the Mute + Snooze row so every button on the screen lines up.
        val controls = CappedColumn(activity, activity.dp(activity.controlWidth)).apply {
            addView(input, LinearLayout.LayoutParams(-1, -2))
            addView(activity.button("Check answer", primary = true) {
                answer(input.text.toString().toIntOrNull())
            }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = activity.dp(BUTTON_GAP) })
        }
        content.addView(controls, LinearLayout.LayoutParams(-1, -2).apply { topMargin = activity.dp(16) })
    }

    private fun board(
        count: Int,
        columns: Int,
        maxSize: Int,
        top: Int = 12,
        decorate: (Button, Int) -> Unit = { _, _ -> },
    ) {
        val tiles = SquareBoard(activity, columns, (count + columns - 1) / columns, maxSize)
        this.tiles = tiles
        repeat(count) { index ->
            val button = activity.button("") { choose(index) }
            button.setPadding(0, 0, 0, 0)
            activity.paintButton(button, false, radius = 12)
            decorate(button, index)
            cells.add(button)
            tiles.addTile(button, index)
        }
        content.addView(tiles, LinearLayout.LayoutParams(-1, -2).apply { topMargin = activity.dp(top) })
    }

    private fun memory(puzzle: WakeRound.Memory) {
        val columns = if (puzzle.faces.size == 6) 3 else 4
        board(puzzle.faces.size, columns, maxSize = 112) { card, index ->
            val art = MemoryCardArt(checkNotNull(activity.getDrawable(faces[puzzle.faces[index]].first)), activity.tint)
            cards.add(art)
            card.foreground = art
        }
        val credit = activity.text(12f).apply {
            setTextColor(activity.tint)
            text = "Spring Vibes by Kiwi · CC BY 4.0"
        }
        content.addView(credit, LinearLayout.LayoutParams(-1, -2).apply { topMargin = activity.dp(10) })
    }

    private fun cups(puzzle: WakeRound.Cups) {
        board(puzzle.count, puzzle.count, maxSize = 96, top = 24) { cup, _ ->
            val shape = CupShape(activity.dp(1).toFloat(), activity.accent, activity.ink)
            cup.foreground = shape
            cups.add(shape)
        }
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
            val distance = cup.width + activity.dp(TILE_GAP)
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
            cards[index].faceUp = visible
            val name = faces[face].second
            describe(cell, "Card ${index + 1}, " + when {
                index in matched -> "$name, matched"
                visible -> name
                else -> "face down"
            })
        }
    }

    private fun paint(button: Button, selected: Boolean) {
        if (button.isSelected == selected) return
        button.isSelected = selected
        activity.paintButton(button, selected, radius = 12)
    }

    private fun showText(view: TextView, value: String) {
        if (view.text.toString() != value) view.text = value
    }

    private fun describe(view: Button, value: String) {
        if (view.contentDescription?.toString() != value) view.contentDescription = value
    }

    companion object {
        private val faces = listOf(
            R.drawable.memorama_bud_sprig to "bud sprig",
            R.drawable.memorama_curling_vine to "curling vine",
            R.drawable.memorama_striped_leaf to "striped leaf",
            R.drawable.memorama_golden_buds to "golden buds",
            R.drawable.memorama_twin_leaves to "twin leaves",
            R.drawable.memorama_pink_blossom to "pink blossom",
            R.drawable.memorama_daisies to "daisies",
            R.drawable.memorama_purple_flower to "purple flower",
        )
    }
}

private const val TILE_GAP = 8
private const val MIN_TILE = 48

/** A vertical column that is never wider than [limit] pixels and centres in wider parents. */
internal class CappedColumn(context: android.content.Context, private val limit: Int) : LinearLayout(context) {
    init { orientation = VERTICAL }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = minOf(MeasureSpec.getSize(widthMeasureSpec), limit)
        super.onMeasure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), heightMeasureSpec)
    }
}

/**
 * Square tiles sized to the board width, including the gaps, and capped by [fitSide] so the
 * whole challenge stays on screen (see [WakeRoundView.fit]).
 */
private class SquareBoard(
    activity: AlarmActivity,
    private val columns: Int,
    val rows: Int,
    maxSize: Int,
) : LinearLayout(activity) {
    var fitSide = Int.MAX_VALUE
    var side = 0
        private set
    private val gap = activity.dp(TILE_GAP)
    private val limit = activity.dp(maxSize)

    init {
        orientation = VERTICAL
        clipChildren = false
    }

    fun addTile(tile: Button, index: Int) {
        val column = index % columns
        if (column == 0) {
            addView(LinearLayout(context).apply {
                gravity = Gravity.CENTER
                clipChildren = false
            }, LayoutParams(-1, -2).apply { if (index > 0) topMargin = gap })
        }
        val row = getChildAt(childCount - 1) as LinearLayout
        row.addView(tile, LayoutParams(limit, limit).apply { if (column > 0) marginStart = gap })
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val previous = side
        side = minOf(((width - gap * (columns - 1)) / columns).coerceIn(1, limit), fitSide)
        for (index in 0 until childCount) {
            val row = getChildAt(index) as LinearLayout
            // Rows cache their measurement for an unchanged width; a new tile size must reach them.
            if (side != previous) row.forceLayout()
            for (column in 0 until row.childCount) {
                row.getChildAt(column).layoutParams.apply {
                    this.width = side
                    height = side
                }
            }
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }
}

private class MemoryCardArt(private val icon: Drawable, tint: Int) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = tint
        style = Paint.Style.STROKE
    }
    var faceUp = false
        set(value) {
            if (field == value) return
            field = value
            invalidateSelf()
        }

    override fun draw(canvas: Canvas) {
        val size = minOf(bounds.width(), bounds.height())
        val x = bounds.exactCenterX()
        val y = bounds.exactCenterY()
        if (faceUp) {
            val side = (size * 0.8f).roundToInt()
            val left = (x - side / 2f).roundToInt()
            val top = (y - side / 2f).roundToInt()
            icon.setBounds(left, top, left + side, top + side)
            icon.draw(canvas)
        } else {
            val half = size * 0.13f
            paint.strokeWidth = size * 0.026f
            canvas.save()
            canvas.rotate(45f, x, y)
            canvas.drawRoundRect(x - half, y - half, x + half, y + half, half / 3, half / 3, paint)
            canvas.restore()
        }
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
        icon.alpha = alpha
    }
    override fun setColorFilter(colorFilter: ColorFilter?) {
        paint.colorFilter = colorFilter
        icon.colorFilter = colorFilter
    }
    @Deprecated("Drawable opacity is no longer consulted by Android")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
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
