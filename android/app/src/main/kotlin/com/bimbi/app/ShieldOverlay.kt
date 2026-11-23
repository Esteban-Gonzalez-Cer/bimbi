package com.bimbi.app

import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.text.format.DateFormat
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Date
import kotlin.math.roundToInt

/**
 * Full-screen pause card drawn over a covered app. It uses the native wake
 * screen's look: night surface, Instrument Serif title and a 56dp button.
 * The only action is Go home; Android back also goes home.
 */
internal class ShieldOverlay(private val context: Context) {
    private val windows = context.getSystemService(WindowManager::class.java)
    private var root: View? = null
    private var title: TextView? = null
    private var detail: TextView? = null
    private var shown: Shield? = null
    private var shownMinute = -1L

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).roundToInt()

    fun show(shield: Shield, now: Long) {
        val view = root ?: build().also { attach(it) }
        val minute = now / 60_000
        if (shield == shown && minute == shownMinute) return
        val sameKind = shown?.let { it::class == shield::class } == true
        shown = shield
        shownMinute = minute
        val (heading, body) = when (shield) {
            is Shield.Focus -> {
                val left = ((shield.until - now + 59_999) / 60_000).coerceAtLeast(1)
                "Paused during Focus" to
                    "$left min left · back at ${DateFormat.getTimeFormat(context).format(Date(shield.until))}"
            }
            is Shield.Limit -> {
                val used = (shield.usedMs / 60_000).coerceAtLeast(shield.limitMinutes.toLong())
                "Daily limit reached" to "$used of ${shield.limitMinutes} min used today · resets at midnight"
            }
        }
        title?.text = heading
        detail?.text = body
        view.contentDescription = "$heading. $body"
        if (!sameKind) view.announceForAccessibility("$heading. $body")
    }

    fun hide() {
        val view = root ?: return
        runCatching { windows.removeView(view) }
        root = null
        shown = null
        shownMinute = -1
    }

    private fun attach(view: View) {
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE,
        )
        if (Build.VERSION.SDK_INT >= 28) {
            params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        windows.addView(view, params)
        root = view
    }

    private fun goHome() {
        hide()
        context.startActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    private fun build(): View {
        val ink = context.getColor(R.color.bimbi_text_on_night)
        val tint = context.getColor(R.color.bimbi_lavender)
        val res = context.resources
        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        column.addView(ImageView(context).apply {
            setImageResource(R.drawable.ic_bimbi_buddy)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(dp(112), dp(112)))
        title = TextView(context).apply {
            textSize = 34f
            typeface = res.getFont(R.font.instrument_serif_regular)
            setTextColor(ink)
            gravity = Gravity.CENTER
            if (Build.VERSION.SDK_INT >= 28) isAccessibilityHeading = true
        }
        column.addView(title, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(20) })
        detail = TextView(context).apply {
            textSize = 16f
            typeface = res.getFont(R.font.nunito_medium)
            setTextColor(tint)
            gravity = Gravity.CENTER
        }
        column.addView(detail, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(8) })
        column.addView(TextView(context).apply {
            textSize = 13f
            typeface = res.getFont(R.font.nunito_medium)
            setTextColor(tint)
            gravity = Gravity.CENTER
            alpha = 0.8f
            text = "Bimbi's Focus shield is a gentle pause, not a lock. You can turn it off in Bimbi or Android settings."
        }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(20) })
        column.addView(Button(context).apply {
            text = "Go home"
            textSize = 15f
            typeface = res.getFont(R.font.nunito_extrabold)
            isAllCaps = false
            minHeight = dp(56)
            minimumHeight = dp(56)
            stateListAnimator = null
            setTextColor(context.getColor(R.color.bimbi_on_lilac))
            background = RippleDrawable(
                ColorStateList.valueOf(tint),
                GradientDrawable().apply {
                    cornerRadius = dp(16).toFloat()
                    setColor(context.getColor(R.color.bimbi_lilac_accent))
                },
                null,
            )
            setOnClickListener { goHome() }
        }, LinearLayout.LayoutParams(-1, -2).apply { topMargin = dp(32) })

        return object : FrameLayout(context) {
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                    if (event.action == KeyEvent.ACTION_UP) goHome()
                    return true
                }
                return super.dispatchKeyEvent(event)
            }
        }.apply {
            setBackgroundColor(context.getColor(R.color.bimbi_night))
            isFocusable = true
            isFocusableInTouchMode = true
            setPadding(dp(24), dp(24), dp(24), dp(24))
            addView(column, FrameLayout.LayoutParams(minOf(dp(420), res.displayMetrics.widthPixels - dp(48)), -2, Gravity.CENTER))
        }
    }
}
