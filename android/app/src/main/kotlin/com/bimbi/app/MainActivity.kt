package com.bimbi.app

import android.Manifest
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
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AlarmEngine.channels(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bimbi.app/platform").setMethodCallHandler { call, result ->
            val alarms = AlarmEngine(this)
            try {
                when (call.method) {
                    "capabilities" -> {
                        val meta = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA).metaData
                        result.success(mapOf("exactAlarm" to alarms.exactAllowed(), "notifications" to alarms.notificationsAllowed(),
                            "fullScreen" to alarms.fullScreenAllowed(), "pending" to alarms.pending(), "active" to (alarms.active() != null),
                            "lastEvent" to alarms.lastEvent(), "model" to Build.MODEL, "api" to Build.VERSION.SDK_INT,
                            "mapsConfigured" to !meta.getString("com.google.android.geo.API_KEY").isNullOrBlank(),
                            "accelerometer" to (getSystemService(SensorManager::class.java).getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                            "gps" to packageManager.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS), "usageAccess" to usageAllowed()))
                    }
                    "schedule" -> { alarms.schedule(call.argument<String>("id")!!, call.argument<Number>("atMillis")!!.toLong(), call.argument<Number>("intervalSeconds")!!.toLong()); result.success(null) }
                    "cancel" -> { alarms.cancel(); result.success(null) }
                    "dismiss" -> { alarms.dismiss(); result.success(null) }
                    "exactSettings" -> { if (Build.VERSION.SDK_INT >= 31) startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName"))); result.success(null) }
                    "fullScreenSettings" -> { if (Build.VERSION.SDK_INT >= 34) startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))); result.success(null) }
                    "notificationSettings" -> {
                        if (Build.VERSION.SDK_INT >= 33 && !alarms.notificationsAllowed()) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 400)
                        else startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
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
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) { result.error("permission_denied", "Android permission is missing or revoked", null) }
            catch (e: IllegalStateException) { result.error(if (e.message?.contains("permission_denied") == true) "permission_denied" else "platform_error", e.message, null) }
            catch (_: Exception) { result.error("platform_error", "Android could not complete the operation", null) }
        }
    }
    private fun usageAllowed(): Boolean = getSystemService(AppOpsManager::class.java).checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
}
