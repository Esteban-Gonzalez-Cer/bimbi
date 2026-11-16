package com.bimbi.app

import android.app.Activity
import android.content.*
import android.os.*
import android.view.Gravity
import android.widget.*
import android.window.OnBackInvokedDispatcher

/** Entire dismissal flow works without a Flutter engine or network. */
class AlarmActivity : Activity() {
    private val dismissed = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) { finish() }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { AlarmEngine(this).dismiss(); finish() }
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(dismissed, IntentFilter("com.bimbi.app.ALARM_DISMISSED"), RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") registerReceiver(dismissed, IntentFilter("com.bimbi.app.ALARM_DISMISSED"))
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(32, 48, 32, 48)
            setBackgroundColor(0xfffff7ed.toInt())
        }
        content.addView(TextView(this).apply { text = "Good morning\nBimbi wake alarm"; textSize = 30f; gravity = Gravity.CENTER; setTextColor(0xff302c3e.toInt()) })
        content.addView(Button(this).apply {
            text = "Dismiss alarm"; textSize = 22f; minHeight = 96
            setOnClickListener { AlarmEngine(this@AlarmActivity).dismiss(); finish() }
        })
        setContentView(ScrollView(this).apply { isFillViewport = true; addView(content) })
    }
    override fun onResume() { super.onResume(); if (AlarmEngine(this).active() == null) finish() }
    override fun onDestroy() { unregisterReceiver(dismissed); super.onDestroy() }
    @Deprecated("Native emergency dismissal")
    override fun onBackPressed() { AlarmEngine(this).dismiss(); super.onBackPressed() }
}
