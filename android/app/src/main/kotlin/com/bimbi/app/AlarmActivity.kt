package com.bimbi.app

import android.app.Activity
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.format.DateFormat
import android.text.SpannableString
import android.text.Spanned
import android.text.TextUtils
import android.text.style.ForegroundColorSpan
import android.text.style.RelativeSizeSpan
import android.text.style.TypefaceSpan
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import android.view.accessibility.AccessibilityManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** Native wake surface. Back leaves this window while the foreground alarm keeps running. */
class AlarmActivity : Activity(), SensorEventListener {
    private val handler = Handler(Looper.getMainLooper())
    private val engine by lazy { AlarmEngine(this) }
    private val sensors by lazy { getSystemService(SensorManager::class.java) }
    private lateinit var bar: ProgressBar
    private lateinit var clock: TextView
    private lateinit var header: TextView
    private lateinit var challengeTitle: TextView
    private lateinit var roundLabel: TextView
    private lateinit var status: TextView
    private lateinit var mute: Button
    private lateinit var snooze: Button
    private lateinit var alternative: Button
    private lateinit var body: LinearLayout
    private lateinit var controls: LinearLayout
    private var currentRound: WakeRoundView? = null
    private var displayedSession: WakeSession? = null
    private var displayedAttempt = -1
    private var distinctSecond = -1
    private var sensorRegistered = false
    private val shakeDetector = ShakeDetector()
    private var serviceRequested = false
    private var viewportHeight = 0

    internal val ink by lazy { getColor(R.color.bimbi_text_on_night) }
    private val night by lazy { getColor(R.color.bimbi_night) }
    internal val accent by lazy { getColor(R.color.bimbi_lilac_accent) }
    internal val tint by lazy { getColor(R.color.bimbi_lavender) }
    private val onAccent by lazy { getColor(R.color.bimbi_on_lilac) }
    internal val raised by lazy { getColor(R.color.bimbi_night_raised) }
    private val surface by lazy { getColor(R.color.bimbi_night_high) }
    private val bodyFont by lazy { resources.getFont(R.font.nunito_medium) }
    internal val strongFont by lazy { resources.getFont(R.font.nunito_extrabold) }
    private val headingFont by lazy { resources.getFont(R.font.instrument_serif_regular) }
    internal val splitLayout: Boolean
        get() = resources.configuration.run {
            orientation == Configuration.ORIENTATION_LANDSCAPE && screenWidthDp >= 740 && fontScale < 1.5f
        }

    /** Width of the content column: one column on phones and portrait, two panes in landscape. */
    private val contentWidth get() = minOf(resources.configuration.screenWidthDp - 2 * gutter, if (splitLayout) 792 else 432)
    private val gutter get() = if (splitLayout) 24 else 16

    /**
     * Every full-width control on this screen (Mute + Snooze row, answer field, Check answer)
     * shares one width so the buttons line up. In landscape that is the left pane.
     */
    internal val controlWidth get() = if (splitLayout) (contentWidth - PANE_GAP) * 2 / 5 else contentWidth

    private val updateScreen = object : Runnable {
        override fun run() {
            render()
            if (!isFinishing) handler.postDelayed(this, 40)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeControlStream = AudioManager.STREAM_ALARM
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        window.decorView.setBackgroundColor(night)
        buildLayout()
    }

    internal fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()

    internal fun text(size: Float, heading: Boolean = false) = TextView(this).apply {
        textSize = size
        setTextColor(ink)
        typeface = if (heading) headingFont else bodyFont
        gravity = Gravity.CENTER
        includeFontPadding = false
    }

    /** One button style for the whole screen: 56dp tall, 16dp corners, Nunito ExtraBold 15sp. */
    internal fun button(label: String, primary: Boolean = false, action: () -> Unit) = Button(this).apply {
        text = label
        textSize = 15f
        typeface = strongFont
        isAllCaps = false
        minHeight = dp(BUTTON_HEIGHT)
        minimumHeight = dp(BUTTON_HEIGHT)
        minimumWidth = 0
        minWidth = 0
        stateListAnimator = null
        setLineSpacing(0f, 1.05f)
        setPadding(dp(12), dp(8), dp(12), dp(8))
        paintButton(this, primary)
        setOnClickListener {
            interaction()
            action()
        }
    }

    internal fun paintButton(button: Button, selected: Boolean, radius: Int = 16) {
        val shape = GradientDrawable().apply {
            cornerRadius = dp(radius).toFloat()
            setColor(if (selected) accent else surface)
        }
        button.background = RippleDrawable(ColorStateList.valueOf(tint), shape, null)
        button.setTextColor(if (selected) onAccent else ink)
    }

    private fun buildLayout() {
        val frame = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(night)
            setOnApplyWindowInsetsListener { view, insets ->
                if (Build.VERSION.SDK_INT >= 30) {
                    val safe = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout() or WindowInsets.Type.ime())
                    view.setPadding(safe.left, safe.top, safe.right, safe.bottom)
                } else {
                    @Suppress("DEPRECATION")
                    view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                        insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
                }
                insets
            }
        }
        bar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = ACTIVE_WINDOW_MS.toInt()
            progress = max
            progressTintList = ColorStateList.valueOf(tint)
            progressBackgroundTintList = ColorStateList.valueOf(surface)
            contentDescription = "Activity timer: 15 seconds"
            minimumHeight = dp(48)
            setPadding(0, dp(20), 0, dp(20))
            setOnClickListener { interaction() }
        }
        val timer = FrameLayout(this).apply {
            setPadding(dp(gutter), 0, dp(gutter), 0)
            addView(CappedColumn(this@AlarmActivity, dp(contentWidth)).apply {
                addView(bar, LinearLayout.LayoutParams(-1, dp(48)))
            }, FrameLayout.LayoutParams(-1, -2, Gravity.CENTER))
        }
        frame.addView(timer, LinearLayout.LayoutParams(-1, -2))

        // Hierarchy: alarm label (eyebrow) → time (display) → challenge (heading) → round (caption).
        val details = column()
        header = text(15f).apply {
            typeface = strongFont
            setTextColor(tint)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
        }
        details.addView(header, spaced())
        clock = text(44f, heading = true)
        details.addView(clock, spaced(4))
        challengeTitle = text(26f, heading = true).apply {
            if (Build.VERSION.SDK_INT >= 28) isAccessibilityHeading = true
        }
        details.addView(challengeTitle, spaced(18))
        roundLabel = text(14f).apply { setTextColor(tint) }
        details.addView(roundLabel, spaced(4))

        body = column()
        status = text(14f).apply {
            minimumHeight = dp(24)
            setTextColor(tint)
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        val challenge = column().apply {
            addView(body, spaced())
            addView(status, spaced(12))
        }

        mute = button("Mute") {
            displayedSession?.episode?.id?.let { AlarmService.current?.mute(it) }
        }
        snooze = button("Snooze") {
            displayedSession?.episode?.id?.let { AlarmService.current?.postpone(it) }
        }
        alternative = button("Use math challenge") {
            displayedSession?.fallbackToMath()
        }.apply { visibility = View.GONE }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            isBaselineAligned = false
            addView(mute, LinearLayout.LayoutParams(0, -1, 1f))
            addView(snooze, LinearLayout.LayoutParams(0, -1, 1f).apply { marginStart = dp(BUTTON_GAP) })
        }
        controls = CappedColumn(this@AlarmActivity, dp(controlWidth)).apply {
            addView(actions, spaced())
            addView(alternative, spaced(BUTTON_GAP))
        }
        val content = CappedColumn(this@AlarmActivity, dp(contentWidth)).apply {
            if (splitLayout) {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                details.addView(controls, spaced(28))
                addView(details, LinearLayout.LayoutParams(0, -2, 2f))
                addView(challenge, LinearLayout.LayoutParams(0, -2, 3f).apply { marginStart = dp(PANE_GAP) })
            } else {
                addView(details, spaced())
                addView(challenge, spaced(28))
                addView(controls, spaced(20))
            }
        }
        val scroll = ScrollView(this).apply { isFillViewport = true }
        val page = FrameLayout(this).apply {
            setPadding(dp(gutter), dp(16), dp(gutter), dp(24))
            addView(content, FrameLayout.LayoutParams(-1, -2, Gravity.CENTER))
        }
        scroll.addView(page)
        // Keep the whole challenge, including Mute and Snooze, on screen: when the page overflows
        // the visible area the board gives up the difference. A new visible size starts over.
        // Layout requests made inside a layout callback can wait for an unrelated frame, so the
        // adjustment runs as its own message right after this pass.
        val fitToScreen = Runnable {
            val visible = scroll.height
            if (visible != viewportHeight) {
                viewportHeight = visible
                if (currentRound?.resetFit() == true) return@Runnable
            }
            val overflow = page.height - visible
            if (visible > 0 && overflow > 0) currentRound?.fit(overflow)
        }
        scroll.viewTreeObserver.addOnGlobalLayoutListener {
            handler.removeCallbacks(fitToScreen)
            handler.post(fitToScreen)
        }
        frame.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(frame)
    }

    private fun column() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
    }

    private fun spaced(top: Int = 0) = LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(top) }

    override fun onStart() {
        super.onStart()
        serviceRequested = false
        updateScreen.run()
    }

    override fun onStop() {
        handler.removeCallbacks(updateScreen)
        setSensor(false)
        super.onStop()
    }

    private fun render() {
        val service = AlarmService.current
        val session = service?.session
        if (service == null || session == null) {
            val pending = runCatching { engine.active() }.getOrNull()
            if (pending == null) {
                finish()
                return
            }
            controls.visibility = View.INVISIBLE
            if (!serviceRequested) {
                serviceRequested = true
                if (engine.notificationsAllowed()) AlarmService.start(this)
                header.text = "Opening your challenge…"
                if (!engine.notificationsAllowed()) status.text = "Allow Bimbi notifications in Android settings."
            }
            return
        }
        serviceRequested = false
        controls.visibility = View.VISIBLE
        val id = session.episode.id
        service.showRound(id)
        val now = SystemClock.elapsedRealtime()
        val elapsed = now - (session.shownAt ?: now)
        if (displayedSession !== session || displayedAttempt != session.attempt) {
            val expected = session.attempt
            if (displayedSession !== session) {
                val time = Date(session.episode.scheduledAt)
                val day = SimpleDateFormat("EEE", Locale.getDefault()).format(time)
                clock.text = "$day ${DateFormat.getTimeFormat(this).format(time)}"
            }
            displayedSession = session
            displayedAttempt = expected
            shakeDetector.reset()
            header.text = session.episode.label
            challengeTitle.text = session.challenge.title
            roundLabel.text = "Round ${session.round} of ${session.totalRounds}"
            body.removeAllViews()
            currentRound = WakeRoundView(this, session.board, body, choose = { cell ->
                service.session?.takeIf { it === session }?.choose(SystemClock.elapsedRealtime(), expected, cell)
                service.refresh()
            }, answer = { value ->
                service.session?.takeIf { it === session }?.answer(SystemClock.elapsedRealtime(), expected, value)
                service.refresh()
            })
        }
        val remaining = ((session.deadline ?: now) - now).coerceIn(0L, ACTIVE_WINDOW_MS)
        bar.progress = remaining.toInt()
        val seconds = ((remaining + 999) / 1_000).toInt()
        if (seconds != distinctSecond) {
            distinctSecond = seconds
            bar.contentDescription = "Activity timer: $seconds seconds"
        }
        val mutedText = if (session.muted) "Resume sound" else "Mute"
        if (mute.text.toString() != mutedText) mute.text = mutedText
        snooze.isEnabled = !session.episode.isTest && session.episode.snoozesLeft > 0
        snooze.alpha = if (snooze.isEnabled) 1f else 0.6f
        snooze.visibility = if (session.episode.isTest) View.GONE else View.VISIBLE
        val left = session.episode.snoozesLeft
        val snoozeText = "Snooze 5 min\n$left left"
        if (snooze.text.toString() != snoozeText) {
            snooze.contentDescription = "Snooze 5 minutes, $left left"
            snooze.text = SpannableString(snoozeText).apply {
                val start = snoozeText.indexOf('\n') + 1
                setSpan(RelativeSizeSpan(0.87f), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                if (Build.VERSION.SDK_INT >= 28) setSpan(TypefaceSpan(bodyFont), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                setSpan(ForegroundColorSpan(tint), start, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }
        val spokenNavigation = getSystemService(AccessibilityManager::class.java).isTouchExplorationEnabled
        alternative.visibility = if (spokenNavigation && session.challenge in setOf(
                WakeChallenge.CUPS, WakeChallenge.PATTERN, WakeChallenge.MEMORY
            )) android.view.View.VISIBLE else android.view.View.GONE
        val message = service.error.ifEmpty { session.feedback }
        if (status.text.toString() != message) status.text = message
        setSensor(session.challenge == WakeChallenge.SHAKE)
        currentRound?.refresh(session, elapsed)
    }

    internal fun interaction() {
        displayedSession?.episode?.id?.let { AlarmService.current?.interact(it) }
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked == MotionEvent.ACTION_DOWN) interaction()
        return super.dispatchTouchEvent(event)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0 &&
            event.keyCode !in setOf(KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_POWER, KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_UP)
        ) interaction()
        return super.dispatchKeyEvent(event)
    }

    private fun setSensor(enabled: Boolean) {
        if (sensorRegistered == enabled) return
        if (enabled) {
            val accelerometer = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            sensorRegistered = accelerometer != null &&
                runCatching { sensors.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME) }.getOrDefault(false)
            if (!sensorRegistered) displayedSession?.fallbackToMath()
        } else {
            sensors.unregisterListener(this)
            sensorRegistered = false
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        val session = displayedSession ?: return
        val service = AlarmService.current ?: return
        if (service.session !== session || session.challenge != WakeChallenge.SHAKE) return
        val magnitude = sqrt(event.values.take(3).sumOf { (it * it).toDouble() })
        if (shakeDetector.sample(magnitude, event.timestamp / 1_000_000)) {
            session.shake(SystemClock.elapsedRealtime(), displayedAttempt)
            service.refresh()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}

internal const val BUTTON_HEIGHT = 56
internal const val BUTTON_GAP = 12
private const val PANE_GAP = 40

internal class ShakeDetector {
    private var high = false
    private var last = Long.MIN_VALUE / 2

    fun reset() { high = false }

    fun sample(magnitude: Double, at: Long): Boolean {
        val motion = abs(magnitude - SensorManager.GRAVITY_EARTH)
        if (motion < 1.35) high = false
        if (motion < 2.9 || high) return false
        high = true
        if (at - last < 240) return false
        last = at
        return true
    }
}
