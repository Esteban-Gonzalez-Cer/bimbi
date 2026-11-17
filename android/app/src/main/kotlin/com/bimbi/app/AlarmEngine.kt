package com.bimbi.app

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import org.json.JSONObject

/** Single persisted experimental alarm. Native Android is the source of truth. */
class AlarmEngine(private val context: Context) {
    private val prefs = context.getSharedPreferences("bimbi_alarm", Context.MODE_PRIVATE)
    private val manager = context.getSystemService(AlarmManager::class.java)
    private val notifications = context.getSystemService(NotificationManager::class.java)

    fun exactAllowed() = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
    fun notificationsAllowed() = notifications.areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
        notifications.getNotificationChannel("bimbi_alarm")?.importance != NotificationManager.IMPORTANCE_NONE
    fun fullScreenAllowed() = Build.VERSION.SDK_INT < 34 || notifications.canUseFullScreenIntent()
    fun pending(): Map<String, Any>? = prefs.getString("pending", null)?.let {
        val value = JSONObject(it)
        mapOf("id" to value.getString("id"), "atMillis" to value.getLong("atMillis"), "intervalSeconds" to value.getLong("intervalSeconds"))
    }
    fun active(): String? = prefs.getString("active", null)
    fun lastEvent(): String = prefs.getString("lastEvent", "No alarm event recorded")!!
    fun event(value: String) {
        prefs.edit().putString("lastEvent", value).commit()
        Log.i("BimbiAlarm", value) // No identity, routes or tokens.
    }
    private fun intent(id: String, at: Long): PendingIntent = PendingIntent.getBroadcast(
        context, 100, Intent(context, AlarmReceiver::class.java).putExtra("id", id).putExtra("atMillis", at),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun schedule(id: String, at: Long, intervalSeconds: Long) {
        require(id.isNotBlank() && id.length <= 80 && at > System.currentTimeMillis()) { "Invalid future alarm" }
        require(intervalSeconds == 0L || intervalSeconds >= 60L) { "Minimum repeat interval is 60 seconds" }
        check(exactAllowed()) { "exact_permission_denied" }
        check(notificationsAllowed()) { "notification_permission_denied" }
        val next = JSONObject().put("id", id).put("atMillis", at).put("intervalSeconds", intervalSeconds)
        // Commit before registering with the OS so boot recovery has a durable record.
        check(prefs.edit().putString("pending", next.toString()).commit()) { "persistence_failed" }
        try {
            manager.setAlarmClock(AlarmManager.AlarmClockInfo(at,
                PendingIntent.getActivity(context, 101, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)), intent(id, at))
            event("scheduled:$at")
        } catch (e: Exception) {
            prefs.edit().remove("pending").commit()
            manager.cancel(intent(id, at))
            throw e
        }
    }
    fun cancel() {
        manager.cancel(intent("", 0))
        prefs.edit().remove("pending").commit()
        dismiss()
        event("cancelled")
    }
    fun dismiss() {
        prefs.edit().remove("active").commit()
        context.stopService(Intent(context, AlarmService::class.java))
        notifications.cancel(200)
        context.sendBroadcast(Intent("com.bimbi.app.ALARM_DISMISSED").setPackage(context.packageName))
        event("dismissed")
    }
    fun fire(id: String?, at: Long): Boolean {
        val record = pending() ?: return false
        if (record["id"] != id || record["atMillis"] != at) return false
        // Access can change after scheduling. Never start audio without a
        // notification through which the owner can reach Dismiss.
        if (!notificationsAllowed()) {
            cancel()
            event("delivery_notification_permission_denied")
            return false
        }
        prefs.edit().remove("pending").putString("active", id).commit()
        val repeat = record["intervalSeconds"] as Long
        if (repeat > 0 && exactAllowed() && notificationsAllowed()) {
            val interval = repeat * 1000
            val next = at + ((System.currentTimeMillis() - at).coerceAtLeast(0) / interval + 1) * interval
            try { schedule(id!!, next, repeat) } catch (_: Exception) { event("repeat_restore_failed") }
        }
        val power = context.getSystemService(PowerManager::class.java)
        event("fired:scheduled=$at:actual=${System.currentTimeMillis()}:powerSave=${power.isPowerSaveMode}:deviceIdle=${power.isDeviceIdleMode}:interactive=${power.isInteractive}")
        return true
    }
    fun restore() {
        val record = pending() ?: return
        if (!exactAllowed() || !notificationsAllowed()) { event("restore_permission_denied"); return }
        var at = record["atMillis"] as Long
        val repeat = record["intervalSeconds"] as Long
        if (at <= System.currentTimeMillis()) {
            if (repeat == 0L) {
                prefs.edit().remove("pending").commit()
                event("missed_during_downtime")
                return
            }
            val interval = repeat * 1000
            at += ((System.currentTimeMillis() - at) / interval + 1) * interval
        }
        try { schedule(record["id"] as String, at, repeat) } catch (_: Exception) { event("restore_failed") }
    }
    companion object {
        fun channels(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            val alarms = NotificationChannel("bimbi_alarm", "Wake alarms", NotificationManager.IMPORTANCE_HIGH)
            // Audio is owned by AlarmService and stopped by both dismissal paths.
            alarms.setSound(null, null)
            alarms.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            manager.createNotificationChannel(alarms)
            manager.createNotificationChannel(NotificationChannel("bimbi_messages", "Bimbi messages", NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val engine = AlarmEngine(context)
        if (intent.action == "dismiss") { engine.dismiss(); return }
        if (!engine.fire(intent.getStringExtra("id"), intent.getLongExtra("atMillis", 0))) return
        try { context.startForegroundService(Intent(context, AlarmService::class.java)) }
        catch (_: Exception) { engine.event("alert_service_failed"); AlarmService.postFallback(context) }
    }
}
class RestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED, AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)) AlarmEngine(context).restore()
    }
}
