package com.bimbi.app

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.*
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.net.Uri
import android.os.*
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var alarmEvents: EventChannel.EventSink? = null
    private var reconciledOnLaunch = false
    private val alarmChanges = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            alarmEvents?.success(null)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter(AlarmEngine.CHANGED)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(alarmChanges, filter, RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") registerReceiver(alarmChanges, filter)
    }

    override fun onResume() {
        super.onResume()
        val alarms = AlarmEngine(this)
        runCatching { alarms.restore(forceRearm = !reconciledOnLaunch) }
            .onSuccess { reconciledOnLaunch = true }
            .onFailure { alarms.event("resume_restore_failed") }
    }

    override fun onPause() {
        AlarmPreview.stop()
        super.onPause()
    }

    override fun onDestroy() {
        unregisterReceiver(alarmChanges)
        alarmEvents = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmEngine.channels(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bimbi.app/alarms").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { alarmEvents = events }
                override fun onCancel(arguments: Any?) { alarmEvents = null }
            }
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bimbi.app/platform").setMethodCallHandler { call, result ->
            val alarms = AlarmEngine(this)
            try {
                when (call.method) {
                    "capabilities" -> {
                        val meta = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA).metaData
                        result.success(mapOf("exactAlarm" to alarms.exactAllowed(), "notifications" to alarms.notificationsAllowed(),
                            "fullScreen" to alarms.fullScreenAllowed(), "alarms" to alarms.view(), "active" to (alarms.active() != null),
                            "alarmTones" to AlarmTone.entries.map { mapOf("id" to it.wire, "title" to it.title, "plus" to it.plus) },
                            "alarmIntensities" to AlarmIntensity.entries.map { intensity ->
                                mapOf(
                                    "id" to intensity.wire, "title" to intensity.title,
                                    "available" to (!intensity.needsBoost || AlarmAudio.boostAvailable),
                                )
                            },
                            "snoozedUntil" to alarms.nextSnooze(), "lastWake" to alarms.lastWake(),
                            "lastEvent" to alarms.lastEvent(), "model" to Build.MODEL, "api" to Build.VERSION.SDK_INT,
                            "mapsConfigured" to !meta.getString("com.google.android.geo.API_KEY").isNullOrBlank(),
                            "accelerometer" to (getSystemService(SensorManager::class.java).getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                            "gps" to packageManager.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS), "usageAccess" to usageAllowed()))
                    }
                    "schedule" -> { alarms.scheduleTest(call.argument<String>("id")!!, call.argument<Number>("atMillis")!!.toLong(), call.argument<Number>("intervalSeconds")!!.toLong()); result.success(null) }
                    "cancel" -> { alarms.cancelTest(); result.success(null) }
                    "saveAlarm" -> result.success(alarms.saveDraft(
                        id = call.argument<String>("id"),
                        label = call.argument<String>("label").orEmpty(),
                        hour = requireNotNull(call.argument<Int>("hour")),
                        minute = requireNotNull(call.argument<Int>("minute")),
                        days = call.argument<List<Int>>("days").orEmpty().toSet(),
                        challenge = requireNotNull(WakeChallenge.parse(call.argument<String>("challenge"))),
                        difficulty = requireNotNull(WakeDifficulty.parse(call.argument<String>("difficulty"))),
                        sound = call.alarmSound(),
                    ))
                    "previewAlarmSound" -> {
                        if (alarms.active() != null) {
                            result.error("alarm_active", "Finish the active alarm to preview a sound.", null)
                        } else {
                            result.success(AlarmPreview.play(this, call.alarmSound()))
                        }
                    }
                    "stopAlarmPreview" -> { AlarmPreview.stop(); result.success(null) }
                    "enableAlarm" -> result.success(alarms.setEnabled(
                        requireNotNull(call.argument<String>("id")),
                        requireNotNull(call.argument<Boolean>("enabled")),
                    ))
                    "deleteAlarm" -> { alarms.delete(requireNotNull(call.argument<String>("id"))); result.success(null) }
                    "openChallenge" -> {
                        if (alarms.active() != null) startActivity(Intent(this, AlarmActivity::class.java))
                        result.success(null)
                    }
                    "exactSettings" -> { if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))); result.success(null) }
                    "fullScreenSettings" -> { if (Build.VERSION.SDK_INT >= 34) startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))); result.success(null) }
                    "notificationSettings" -> {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        result.success(null)
                    }
                    "usageSettings" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(null) }
                    "usageSummary" -> {
                        if (!usageAllowed()) result.error("permission_denied", "Usage Access is not granted", null)
                        else {
                            val end = System.currentTimeMillis()
                            val values = getSystemService(UsageStatsManager::class.java).queryUsageStats(UsageStatsManager.INTERVAL_DAILY, end - 86_400_000, end)
                            result.success(mapOf("observedApps" to values.size, "totalForegroundSeconds" to values.sumOf { it.totalTimeInForeground } / 1000))
                        }
                    }
                    "overlaySettings" -> {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "guardStatus" -> {
                        val store = GuardStore(this)
                        val rules = store.load()
                        result.success(mapOf(
                            "usageAccess" to FocusGuard.usageAllowed(this),
                            "overlay" to FocusGuard.overlayAllowed(this),
                            "focusApps" to rules.focusApps.toList(),
                            "limits" to rules.limits,
                            "focusUntil" to rules.focusUntil,
                            "todayMinutes" to FocusGuard.today(this).mapValues { (it.value / 60_000).toInt() },
                            "lastStop" to store.lastStop(),
                        ))
                    }
                    "installedApps" -> {
                        // Icons take a moment to encode; answer from a worker thread.
                        Thread {
                            val apps = runCatching { launchableApps() }
                            runOnUiThread {
                                apps.onSuccess(result::success)
                                    .onFailure { result.error("platform_error", "Android could not list apps", null) }
                            }
                        }.start()
                    }
                    "setGuardRules" -> {
                        val store = GuardStore(this)
                        val limits = call.argument<Map<String, Int>>("limits").orEmpty().filterValues { it in 1..1440 }
                        store.save(store.load().copy(
                            focusApps = call.argument<List<String>>("focusApps").orEmpty().toSet(),
                            limits = limits,
                        ))
                        FocusGuard.sync(this)
                        result.success(null)
                    }
                    "focusShield" -> {
                        val store = GuardStore(this)
                        val until = call.argument<Number>("until")?.toLong()?.takeIf { it > System.currentTimeMillis() }
                        store.save(store.load().copy(focusUntil = until))
                        FocusGuard.sync(this)
                        // Chimes at each window end and a sparkle at the end; none while paused or idle.
                        val windows = call.argument<List<Number>>("windowEnds").orEmpty().map { it.toLong() }
                        if (until == null) FocusChime.cancel(this) else FocusChime.schedule(this, windows, until)
                        result.success(null)
                    }
                    "playFocusChime" -> {
                        FocusChime.play(applicationContext, call.argument<String>("kind") ?: "done")
                        result.success(null)
                    }
                    "phoneUseBetween" -> result.success(FocusGuard.between(
                        this,
                        requireNotNull(call.argument<Number>("from")).toLong(),
                        requireNotNull(call.argument<Number>("to")).toLong(),
                    )?.div(60_000)?.toInt())
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) { result.error("permission_denied", "Android permission is missing or revoked", null) }
            catch (e: IllegalStateException) { result.error(if (e.message?.contains("permission_denied") == true) "permission_denied" else "platform_error", e.message, null) }
            catch (_: Exception) { result.error("platform_error", "Android could not complete the operation", null) }
        }
    }
    /** Apps with a launcher icon, minus the ones the shield never covers. */
    private fun launchableApps(): List<Map<String, Any>> {
        val exempt = FocusGuard.exemptions(this)
        val size = (48 * resources.displayMetrics.density).toInt()
        return packageManager.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .distinctBy { it.activityInfo.packageName }
            .filter { it.activityInfo.packageName !in exempt }
            .map { info ->
                val bitmap = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
                info.loadIcon(packageManager).apply {
                    setBounds(0, 0, size, size)
                    draw(android.graphics.Canvas(bitmap))
                }
                val png = java.io.ByteArrayOutputStream().also {
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it)
                }.toByteArray()
                mapOf("package" to info.activityInfo.packageName, "label" to info.loadLabel(packageManager).toString(), "icon" to png)
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun usageAllowed(): Boolean = getSystemService(AppOpsManager::class.java).checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
}

private fun MethodCall.alarmSound() = AlarmSound.from(
    argument<String>("tone"), argument<Int>("volume"), AlarmIntensity.parse(argument<String>("intensity")),
)
