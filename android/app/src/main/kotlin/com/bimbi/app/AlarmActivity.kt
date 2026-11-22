package com.bimbi.app

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.app.Activity
import android.content.*
import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.*
import android.text.format.DateFormat
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.*
import android.window.OnBackInvokedDispatcher
import java.util.Date
import kotlin.math.roundToInt

/**
 * Native wake screen. The entire dismissal flow works without a Flutter
 * engine or network. The alarm uses the shared lavender theme.
 */
class AlarmActivity : Activity() {
    private val dismissed = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) { finish() }
    }
    private var wiggle: ObjectAnimator? = null

    private fun dp(value: Int) = (value * resources.displayMetrics.density).roundToInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { AlarmEngine(this).dismiss(); finish() }
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
        else {
            // Android 8.0 uses window flags for the same lock-screen behavior.
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(dismissed, IntentFilter("com.bimbi.app.ALARM_DISMISSED"), RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") registerReceiver(dismissed, IntentFilter("com.bimbi.app.ALARM_DISMISSED"))

        val night = getColor(R.color.bimbi_night)
        val cream = getColor(R.color.bimbi_text_on_night)
        val lavender = getColor(R.color.bimbi_lavender)
        val display = resources.getFont(R.font.instrument_serif_regular)
        val body = resources.getFont(R.font.nunito_medium)
        val strong = resources.getFont(R.font.nunito_extrabold)
        window.decorView.setBackgroundColor(night)

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER
            setPadding(dp(24), dp(48), dp(24), dp(48))
            setBackgroundColor(night)
        }
        val buddy = ImageView(this).apply {
            setImageResource(R.drawable.ic_bimbi_buddy)
            // Decorative: the heading below carries the meaning.
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            layoutParams = LinearLayout.LayoutParams(dp(180), dp(180))
        }
        content.addView(buddy)
        content.addView(TextView(this).apply {
            text = DateFormat.getTimeFormat(this@AlarmActivity).format(Date())
            typeface = display; setTextSize(TypedValue.COMPLEX_UNIT_SP, 72f)
            setTextColor(cream); gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, 0)
        })
        content.addView(TextView(this).apply {
            text = "Rise and shine!"
            typeface = display; setTextSize(TypedValue.COMPLEX_UNIT_SP, 34f)
            setTextColor(cream); gravity = Gravity.CENTER
            if (Build.VERSION.SDK_INT >= 28) isAccessibilityHeading = true
        })
        content.addView(TextView(this).apply {
            text = "Bimbi wake alarm"
            typeface = body; setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTextColor(lavender); gravity = Gravity.CENTER
            setPadding(0, dp(4), 0, dp(32))
        })
        val pill = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE; cornerRadius = dp(999).toFloat()
            setColor(getColor(R.color.bimbi_lilac_accent))
        }
        content.addView(Button(this).apply {
            text = "Dismiss alarm"; isAllCaps = false
            typeface = strong; setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            setTextColor(getColor(R.color.bimbi_on_lilac))
            background = RippleDrawable(ColorStateList.valueOf(getColor(R.color.bimbi_lilac_accent_pressed)), pill, null)
            stateListAnimator = null
            minHeight = dp(72); minimumHeight = dp(72)
            setPadding(dp(32), dp(12), dp(32), dp(12))
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            setOnClickListener { AlarmEngine(this@AlarmActivity).dismiss(); finish() }
        })
        val frame = FrameLayout(this).apply { setBackgroundColor(night) }
        frame.addView(content, FrameLayout.LayoutParams(
            minOf(dp(440), resources.displayMetrics.widthPixels),
            ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
        setContentView(ScrollView(this).apply {
            isFillViewport = true; fitsSystemWindows = true
            setBackgroundColor(night); addView(frame)
        })

        // Bells ring: a gentle wiggle, skipped when the system disables animations.
        if (ValueAnimator.areAnimatorsEnabled()) {
            wiggle = ObjectAnimator.ofFloat(buddy, View.ROTATION, -6f, 6f).apply {
                duration = 180; repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                interpolator = AccelerateDecelerateInterpolator()
                start()
            }
        }
    }
    override fun onResume() { super.onResume(); if (AlarmEngine(this).active() == null) finish() }
    override fun onDestroy() { wiggle?.cancel(); unregisterReceiver(dismissed); super.onDestroy() }
    @Deprecated("Native emergency dismissal")
    override fun onBackPressed() { AlarmEngine(this).dismiss(); super.onBackPressed() }
}
