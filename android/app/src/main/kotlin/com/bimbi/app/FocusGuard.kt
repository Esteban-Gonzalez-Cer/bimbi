package com.bimbi.app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.telecom.TelecomManager
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

/** Private, device-only storage for the Focus shield and daily limits. Never synced. */
internal class GuardStore(context: Context) {
    private val preferences = context.getSharedPreferences("bimbi_guard", Context.MODE_PRIVATE)

    fun load(): GuardRules {
        val json = preferences.getString("rules", null)?.let { runCatching { JSONObject(it) }.getOrNull() }
            ?: return GuardRules()
        val apps = json.optJSONArray("focusApps")
        val limits = json.optJSONObject("limits")
        return GuardRules(
            focusApps = buildSet { if (apps != null) for (i in 0 until apps.length()) add(apps.getString(i)) },
            limits = buildMap {
                if (limits != null) for (pkg in limits.keys()) limits.optInt(pkg).takeIf { it in 1..1440 }?.let { put(pkg, it) }
            },
            focusUntil = json.optLong("focusUntil", 0L).takeIf { it > 0 },
        )
    }

    fun save(rules: GuardRules) {
        val json = JSONObject()
            .put("focusApps", JSONArray(rules.focusApps.sorted()))
            .put("limits", JSONObject(rules.limits.toMap()))
        rules.focusUntil?.let { json.put("focusUntil", it) }
        check(preferences.edit().putString("rules", json.toString()).commit()) { "guard_storage_failed" }
    }

    fun lastStop(): String = preferences.getString("lastStop", "")!!
    fun recordStop(reason: String) = preferences.edit().putString("lastStop", reason).apply()
}

/** Shared helpers for permissions, exemptions and today's usage. */
internal object FocusGuard {
    fun usageAllowed(context: Context): Boolean =
        context.getSystemService(AppOpsManager::class.java).checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName,
        ) == AppOpsManager.MODE_ALLOWED

    fun overlayAllowed(context: Context) = Settings.canDrawOverlays(context)

    fun midnight(now: Long, zone: ZoneId = ZoneId.systemDefault()): Long =
        Instant.ofEpochMilli(now).atZone(zone).toLocalDate().atStartOfDay(zone).toInstant().toEpochMilli()

    /**
     * Apps that are never covered: Bimbi, every launcher, Settings, the dialer,
     * the active keyboard and the system UI. Settings stays reachable so the
     * person can always turn the shield off.
     */
    fun exemptions(context: Context): Set<String> = buildSet {
        add(context.packageName)
        add("com.android.settings")
        add("com.android.systemui")
        add("com.android.emergency")
        add("com.google.android.apps.safetyhub")
        val pm = context.packageManager
        pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            .forEach { add(it.activityInfo.packageName) }
        pm.resolveActivity(Intent(Settings.ACTION_SETTINGS), 0)?.activityInfo?.packageName?.let(::add)
        runCatching { context.getSystemService(TelecomManager::class.java)?.defaultDialerPackage }.getOrNull()?.let(::add)
        Settings.Secure.getString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
            ?.substringBefore('/')?.let(::add)
    }

    /** Folds Usage Access events from [from] to [to] into [tracker]. */
    fun fold(context: Context, tracker: UsageTracker, from: Long, to: Long) {
        if (to <= from) return
        val events = context.getSystemService(UsageStatsManager::class.java).queryEvents(from, to) ?: return
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            val component = event.className ?: pkg
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> tracker.resumed(pkg, component, event.timeStamp)
                UsageEvents.Event.ACTIVITY_PAUSED -> tracker.paused(pkg, component, event.timeStamp)
            }
        }
    }

    /** Foreground minutes per app since local midnight. */
    fun today(context: Context, now: Long = System.currentTimeMillis()): Map<String, Long> {
        if (!usageAllowed(context)) return emptyMap()
        val start = midnight(now)
        return UsageTracker(start).also { fold(context, it, start, now) }.usage(now)
    }

    /** Total foreground minutes between two instants, used for "phone use in bed". */
    fun between(context: Context, from: Long, to: Long): Long? {
        if (!usageAllowed(context) || to <= from) return null
        val usage = UsageTracker(from).also { fold(context, it, from, to) }.usage(to)
        return usage.filterKeys { it != context.packageName }.values.sum()
    }

    /** Starts or stops the service to match the stored rules and permissions. */
    fun sync(context: Context) {
        val rules = GuardStore(context).load()
        val ready = usageAllowed(context) && overlayAllowed(context)
        if (rules.hasWork(System.currentTimeMillis()) && ready) {
            FocusGuardService.start(context)
        } else {
            context.stopService(Intent(context, FocusGuardService::class.java))
        }
    }
}
