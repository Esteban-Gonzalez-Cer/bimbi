package com.bimbi.app

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Color
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
import android.text.TextUtils
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowInsets
import android.view.WindowManager
import android.view.accessibility.AccessibilityManager
import android.widget.Button
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
    private var clock: TextView? = null
    private lateinit var header: TextView
    private lateinit var roundLabel: TextView
    private lateinit var status: TextView
    private lateinit var mute: Button
    private lateinit var snooze: Button
    private lateinit var alternative: Button
    private lateinit var body: LinearLayout
    private var currentRound: WakeRoundView? = null
    private var displayedSession: WakeSession? = null
    private var displayedAttempt = -1
    private var distinctSecond = -1
    private var sensorRegistered = false
    private val shakeDetector = ShakeDetector()
    private var serviceRequested = false

    internal val ink by lazy { getColor(R.color.bimbi_text_on_night) }
    private val night by lazy { getColor(R.color.bimbi_night) }
    internal val accent by lazy { getColor(R.color.bimbi_lilac_accent) }
    internal val tint by lazy { getColor(R.color.bimbi_lavender) }
    private val onAccent by lazy { getColor(R.color.bimbi_on_lilac) }
    private val bodyFont by lazy { resources.getFont(R.font.nunito_medium) }
    private val strongFont by lazy { resources.getFont(R.font.nunito_extrabold) }
    private val headingFont by lazy { resources.getFont(R.font.instrument_serif_regular) }

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
    }

    internal fun button(label: String, action: () -> Unit) = Button(this).apply {
        text = label
        textSize = 16f
        typeface = strongFont
        isAllCaps = false
        minHeight = dp(48)
        minimumHeight = dp(48)
        minimumWidth = 0
        minWidth = 0
        stateListAnimator = null
        setPadding(dp(8), dp(6), dp(8), dp(6))
        paintButton(this, false)
        setOnClickListener {
            interaction()
            action()
        }
    }

    internal fun paintButton(button: Button, selected: Boolean) {
        val shape = GradientDrawable().apply {
            cornerRadius = dp(16).toFloat()
            setColor(if (selected) accent else Color.rgb(59, 45, 72))
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
            progressBackgroundTintList = ColorStateList.valueOf(Color.rgb(71, 56, 83))
            contentDescription = "Activity timer: 15 seconds"
            minimumHeight = dp(48)
            setPadding(dp(12), dp(19), dp(12), dp(19))
            setOnClickListener { interaction() }
        }
        frame.addView(bar, LinearLayout.LayoutParams(-1, dp(48)))

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            setPadding(dp(12), dp(4), dp(12), dp(8))
        }
        val scroll = ScrollView(this).apply {
            isFillViewport = false
            addView(content)
        }
        val sideBySide = resources.configuration.screenWidthDp >= 600
        val details = if (sideBySide) LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(12), dp(12), dp(8))
        } else content
        if (sideBySide || resources.configuration.fontScale < 1.5f) {
            val occurrenceTime = text(26f, heading = true)
            clock = occurrenceTime
            details.addView(occurrenceTime)
        }
        header = text(21f, heading = true).apply {
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            if (Build.VERSION.SDK_INT >= 28) isAccessibilityHeading = true
        }
        details.addView(header)
        roundLabel = text(14f)
        details.addView(roundLabel)

        body = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(0, dp(8), 0, dp(4))
        }
        content.addView(body, LinearLayout.LayoutParams(-1, -2))
        status = text(15f).apply { accessibilityLiveRegion = android.view.View.ACCESSIBILITY_LIVE_REGION_POLITE }
        content.addView(status, LinearLayout.LayoutParams(-1, -2))

        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), 0, dp(12), dp(10))
        }
        mute = button("Mute") {
            displayedSession?.episode?.id?.let { AlarmService.current?.mute(it) }
        }.apply { textSize = 14f }
        snooze = button("Snooze 5 min") {
            displayedSession?.episode?.id?.let { AlarmService.current?.postpone(it) }
        }.apply { textSize = 14f }
        alternative = button("Use math challenge") {
            displayedSession?.fallbackToMath()
        }
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            isBaselineAligned = false
            gravity = Gravity.CENTER_VERTICAL
            addView(mute, LinearLayout.LayoutParams(0, -2, 2f).apply { marginEnd = dp(5) })
            addView(snooze, LinearLayout.LayoutParams(0, -2, 3f).apply { marginStart = dp(5) })
        }
        controls.addView(alternative)
        controls.addView(actions)
        if (sideBySide) {
            details.addView(controls, LinearLayout.LayoutParams(-1, -2))
            val panes = LinearLayout(this).apply {
                addView(details, LinearLayout.LayoutParams(0, -1, 2f))
                addView(scroll, LinearLayout.LayoutParams(0, -1, 3f))
            }
            frame.addView(panes, LinearLayout.LayoutParams(-1, 0, 1f))
        } else {
            frame.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
            frame.addView(controls, LinearLayout.LayoutParams(-1, -2))
        }
        setContentView(frame)
    }

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
            if (!serviceRequested) {
                serviceRequested = true
                if (engine.notificationsAllowed()) AlarmService.start(this)
                header.text = "Opening your challenge…"
                if (!engine.notificationsAllowed()) status.text = "Allow Bimbi notifications in Android settings."
            }
            return
        }
        serviceRequested = false
        val id = session.episode.id
        service.showRound(id)
        val now = SystemClock.elapsedRealtime()
        val elapsed = now - (session.shownAt ?: now)
        if (displayedSession !== session || displayedAttempt != session.attempt) {
            val expected = session.attempt
            if (displayedSession !== session) {
                val time = Date(session.episode.scheduledAt)
                val day = SimpleDateFormat("EEE", Locale.getDefault()).format(time)
                clock?.text = "$day ${DateFormat.getTimeFormat(this).format(time)}"
            }
            displayedSession = session
            displayedAttempt = expected
            shakeDetector.reset()
            header.text = session.episode.label
            roundLabel.text = "${session.challenge.title}  ·  Round ${session.round} of ${session.totalRounds}"
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
        snooze.visibility = if (session.episode.isTest) android.view.View.GONE else android.view.View.VISIBLE
        val snoozeText = "Snooze 5 min\n${session.episode.snoozesLeft} left"
        if (snooze.text.toString() != snoozeText) snooze.text = snoozeText
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
