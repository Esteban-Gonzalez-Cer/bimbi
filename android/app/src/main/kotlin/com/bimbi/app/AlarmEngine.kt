package com.bimbi.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

/** All mutations and receiver callbacks run on Android's main thread. */
internal class AlarmEngine(context: Context) {
    private val app = context.applicationContext
    private val store = AlarmStore(app)
    private val manager = app.getSystemService(AlarmManager::class.java)
    private val notifications = app.getSystemService(NotificationManager::class.java)
    private val debug = app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    private val boot get() = Settings.Global.getInt(app.contentResolver, Settings.Global.BOOT_COUNT, -1)

    fun exactAllowed() = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()
    fun notificationsAllowed() = notifications.areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT < 33 ||
            app.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED) &&
        notifications.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
    fun fullScreenAllowed() = Build.VERSION.SDK_INT < 34 || notifications.canUseFullScreenIntent()
    fun active() = store.load().active
    fun nextSnooze(): Long? = if (blocked() == null) {
        store.load().episodes.mapNotNull { it.snooze?.at }.minOrNull()
    } else null
    fun lastEvent() = store.lastEvent()

    fun event(message: String) {
        store.record(message)
        Log.i("BimbiAlarm", message)
    }

    fun changed() {
        app.sendBroadcast(Intent(CHANGED).setPackage(app.packageName))
    }

    fun view(): List<Map<String, Any?>> {
        val permission = blocked()
        val book = store.load()
        return book.alarms.sortedWith(compareBy({ it.next?.at ?: Long.MAX_VALUE }, { it.hour }, { it.minute })).map { alarm ->
            val schedule = if (alarm.enabled && permission != null) permission else alarm.status
            val episodes = book.episodes.filter { it.alarmId == alarm.id }
            val status = when {
                episodes.isNotEmpty() && permission != null -> permission.wire
                episodes.any { it.snooze == null } -> "ringing"
                episodes.isNotEmpty() -> "snoozed"
                else -> schedule.wire
            }
            mapOf(
                "id" to alarm.id, "label" to alarm.label,
                "hour" to alarm.hour, "minute" to alarm.minute, "days" to alarm.days.sorted(),
                "challenge" to alarm.challenge.wire, "difficulty" to alarm.difficulty.wire,
                "tone" to alarm.sound.tone.wire, "volume" to alarm.sound.volume,
                "intensity" to alarm.sound.intensity.wire,
                "enabled" to alarm.enabled, "status" to status,
                "nextAt" to alarm.next?.at?.takeIf { schedule == AlarmStatus.ARMED },
            )
        }
    }

    fun saveDraft(
        id: String?, label: String, hour: Int, minute: Int, days: Set<Int>,
        challenge: WakeChallenge, difficulty: WakeDifficulty, sound: AlarmSound,
    ): Map<String, Any?> {
        require(hour in 0..23 && minute in 0..59 && days.all { it in 0..6 })
        val book = store.load()
        val old = id?.let { value -> book.alarms.firstOrNull { it.id == value } ?: error("alarm_not_found") }
        val sameTime = old != null && old.hour == hour && old.minute == minute && old.days == days
        val alarm = LocalAlarm(
            id = old?.id ?: UUID.randomUUID().toString(),
            label = label.trim().take(40).ifEmpty { "Wake up" },
            hour = hour, minute = minute, days = days, challenge = challenge, difficulty = difficulty,
            enabled = old?.enabled ?: true,
            onceDay = old?.onceDay?.takeIf { sameTime },
            lastFiredDay = old?.lastFiredDay?.takeIf { sameTime },
            sound = sound,
        )
        val result = replace(book, alarm, alarm.firstAfter(System.currentTimeMillis(), ZoneId.systemDefault()))
        changed()
        return result.viewStatus(alarm.id)
    }

    fun setEnabled(id: String, enabled: Boolean): Map<String, Any?> {
        val book = store.load()
        val old = book.alarms.firstOrNull { it.id == id } ?: error("alarm_not_found")
        if (old.enabled == enabled) return book.viewStatus(id)
        val alarm = old.copy(enabled = enabled, onceDay = null, lastFiredDay = null)
        val result = replace(book, alarm, alarm.firstAfter(System.currentTimeMillis(), ZoneId.systemDefault()))
        changed()
        return result.viewStatus(id)
    }

    fun delete(id: String) {
        val book = store.load()
        val alarm = book.alarms.firstOrNull { it.id == id } ?: return
        store.save(book.copy(alarms = book.alarms.filterNot { it.id == id }))
        alarm.next?.let { cancelIntent("regular", id, it.at) }
        changed()
    }

    private fun AlarmBook.viewStatus(id: String): Map<String, Any?> {
        val alarm = alarms.first { it.id == id }
        return mapOf("status" to alarm.status.wire, "nextAt" to alarm.next?.at?.takeIf {
            alarm.status == AlarmStatus.ARMED
        })
    }

    private fun blocked(): AlarmStatus? = when {
        !exactAllowed() -> AlarmStatus.BLOCKED_EXACT
        !notificationsAllowed() -> AlarmStatus.BLOCKED_NOTIFICATIONS
        else -> null
    }

    private fun replace(book: AlarmBook, alarm: LocalAlarm, target: AlarmTime?): AlarmBook {
        val permission = blocked()
        val previous = book.alarms.firstOrNull { it.id == alarm.id }?.next
        val staged = alarm.copy(
            onceDay = if (alarm.days.isEmpty()) target?.day ?: alarm.onceDay else null,
            enabled = alarm.enabled && target != null,
            next = target,
            status = when {
                !alarm.enabled -> alarm.status.takeIf { it == AlarmStatus.FINISHED || it == AlarmStatus.MISSED }
                    ?: AlarmStatus.OFF
                target == null -> AlarmStatus.MISSED
                else -> permission ?: AlarmStatus.ERROR
            }
        )
        var result = book.put(staged)
        if (result != book) store.save(result)
        if (previous != null && (previous != target || permission != null)) {
            cancelIntent("regular", alarm.id, previous.at)
        }
        if (target != null && permission == null) {
            val registered = runCatching { arm("regular", alarm.id, target.at) }.isSuccess
            if (registered) {
                result = result.put(staged.copy(status = AlarmStatus.ARMED))
                store.save(result)
            } else {
                event("regular_registration_failed")
            }
        }
        return result
    }

    private fun fireIntent(kind: String, id: String, at: Long) =
        Intent(app, AlarmReceiver::class.java).setAction(FIRE)
            .setData(Uri.Builder().scheme("bimbi").authority("alarms")
                .appendPath(kind).appendPath(id).appendPath(at.toString()).build())

    private fun alarmIntent(kind: String, id: String, at: Long, flag: Int): PendingIntent? =
        PendingIntent.getBroadcast(app, 0, fireIntent(kind, id, at), flag or PendingIntent.FLAG_IMMUTABLE)

    private fun arm(kind: String, id: String, at: Long) {
        val show = PendingIntent.getActivity(app, 101, Intent(app, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        manager.setAlarmClock(AlarmManager.AlarmClockInfo(at, show),
            requireNotNull(alarmIntent(kind, id, at, PendingIntent.FLAG_UPDATE_CURRENT)))
    }

    private fun cancelIntent(kind: String, id: String, at: Long) {
        alarmIntent(kind, id, at, PendingIntent.FLAG_NO_CREATE)?.let { pending ->
            manager.cancel(pending)
            pending.cancel()
        }
    }

    fun restore(recomputeTime: Boolean = false, afterBoot: Boolean = false, forceRearm: Boolean = false) {
        channels(app)
        val now = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        var book = migrate(store.load(), zone)
        for (alarm in book.alarms) {
            if (!alarm.enabled) continue
            val next = alarm.next
            // A due broadcast already waiting on the main thread may still be delivered.
            if (!afterBoot && !forceRearm && !recomputeTime && blocked() == null && alarm.status == AlarmStatus.ARMED &&
                next != null && next.at <= now && now - next.at < 30_000
            ) continue
            val target = if (!recomputeTime && next != null && next.at > now) next else alarm.firstAfter(now, zone)
            if (!afterBoot && !forceRearm && !recomputeTime && blocked() == null && alarm.status == AlarmStatus.ARMED &&
                next != null && next == target
            ) continue
            book = replace(book, alarm, target)
        }
        book = restoreSnoozes(book, now, afterBoot, recomputeTime, forceRearm)
        val test = book.test
        if (debug && test != null && blocked() == null) {
            val next = when {
                test.at > now -> test.at
                test.intervalSeconds > 0 -> nextTestTime(test, now)
                else -> null
            }
            if (next != test.at) cancelIntent("test", TEST_ALARM_ID, test.at)
            if (next != test.at) store.save(book.copy(test = next?.let { test.copy(at = it) }))
            next?.let { runCatching { arm("test", TEST_ALARM_ID, it) } }
        }
        changed()
    }

    private fun migrate(book: AlarmBook, zone: ZoneId): AlarmBook {
        val legacy = store.legacy() ?: return book
        val name = legacy.optString("id")
        val at = legacy.optLong("atMillis")
        val interval = legacy.optLong("intervalSeconds")
        val local = Instant.ofEpochMilli(at).atZone(zone)
        val next = when {
            at <= 0 -> book
            debug && name == TEST_ALARM_ID && book.test == null -> book.copy(test = TestAlarm(at, interval))
            name == "bimbi-alarm" && book.alarms.none { it.id == name } -> book.put(
                LocalAlarm(
                    id = name, label = "Wake up", hour = local.hour, minute = local.minute,
                    days = if (interval == 86_400L) (0..6).toSet() else emptySet(),
                    challenge = WakeChallenge.MATH, difficulty = WakeDifficulty.NORMAL,
                    onceDay = local.toLocalDate().takeIf { interval != 86_400L },
                    next = AlarmTime(at, local.toLocalDate()),
                )
            )
            else -> book
        }
        store.save(next, clearLegacy = true)
        PendingIntent.getBroadcast(app, 100, Intent(app, AlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)?.let {
            manager.cancel(it)
            it.cancel()
        }
        event("legacy_migrated")
        return next
    }

    private fun restoreSnoozes(
        book: AlarmBook, now: Long, afterBoot: Boolean, recomputeTime: Boolean, forceRearm: Boolean,
    ): AlarmBook {
        var current = book
        val elapsed = SystemClock.elapsedRealtime()
        val bootCount = boot
        for (episode in book.episodes) {
            val snooze = episode.snooze ?: continue
            val due = if (recomputeTime) snooze.resolve(now, elapsed, bootCount) else snooze.at
            if (due <= now && (afterBoot || snooze.boot != bootCount)) {
                current = current.copy(episodes = current.episodes.filterNot { it.id == episode.id })
                current.alarms.firstOrNull { it.id == episode.alarmId && it.status == AlarmStatus.FINISHED }
                    ?.let { current = current.put(it.copy(status = AlarmStatus.MISSED)) }
                store.save(current)
                cancelIntent("snooze", episode.id, snooze.at)
                event("snooze_missed")
            } else if (blocked() == null) {
                // If an older alarm could not ring because permission was revoked,
                // keep the episode and allow it to return when permission is granted.
                val target = if (due <= now && (forceRearm || now - due >= 30_000)) now + 1_000 else due
                if (target != snooze.at) {
                    current = current.put(episode.copy(snooze = snooze.copy(at = target)))
                    store.save(current)
                    cancelIntent("snooze", episode.id, snooze.at)
                }
                if (target > now || afterBoot) runCatching { arm("snooze", episode.id, target) }
            }
        }
        return current
    }

    fun fire(kind: String, id: String, at: Long): Boolean {
        val now = System.currentTimeMillis()
        if (at > now + 500) return false
        val book = store.load()
        val result = when (kind) {
            "regular" -> fireRegular(book, id, at, now)
            "snooze" -> fireSnooze(book, id, at, now)
            "test" -> fireTest(book, at, now)
            else -> false
        }
        if (result) {
            val power = app.getSystemService(PowerManager::class.java)
            event("fired:$kind:scheduled=$at:actual=$now:powerSave=${power.isPowerSaveMode}:idle=${power.isDeviceIdleMode}")
        }
        changed()
        return result
    }

    private fun fireRegular(book: AlarmBook, id: String, at: Long, now: Long): Boolean {
        val alarm = book.alarms.firstOrNull { it.id == id && it.enabled && it.next?.at == at } ?: return false
        val occurrence = requireNotNull(alarm.next)
        val recurring = alarm.days.isNotEmpty()
        val allowed = blocked() == null
        val consumed = alarm.copy(
            enabled = recurring, lastFiredDay = occurrence.day,
            status = if (recurring) AlarmStatus.ERROR else if (allowed) AlarmStatus.FINISHED else AlarmStatus.MISSED,
        )
        val updated = if (allowed) {
            book.copy(episodes = book.episodes + alarm.startOccurrence(occurrence, now))
        } else book
        val next = consumed.firstAfter(maxOf(now, at), ZoneId.systemDefault())
        replace(updated, consumed, next)
        if (!allowed) event("delivery_blocked_by_permissions")
        return allowed
    }

    private fun fireSnooze(book: AlarmBook, id: String, at: Long, now: Long): Boolean {
        val episode = book.episodes.firstOrNull { it.id == id && it.snooze?.at == at } ?: return false
        val snooze = requireNotNull(episode.snooze)
        val due = snooze.resolve(now, SystemClock.elapsedRealtime(), boot)
        if (due > now + 500) {
            val updated = book.put(episode.copy(snooze = snooze.copy(at = due)))
            store.save(updated)
            if (blocked() == null) runCatching { arm("snooze", id, due) }
            return false
        }
        if (blocked() != null) {
            event("snooze_blocked_by_permissions")
            return false
        }
        store.save(book.copy(episodes = book.episodes.filterNot { it.id == id } +
            episode.resumeFromSnooze(now)))
        return true
    }

    fun snooze(episodeId: String): Boolean {
        val book = store.load()
        val active = book.active?.takeIf { it.id == episodeId } ?: return false
        val episode = active.postpone(System.currentTimeMillis(), SystemClock.elapsedRealtime(), boot) ?: return false
        val next = requireNotNull(episode.snooze).at
        if (blocked() != null) return false
        try {
            arm("snooze", episode.id, next)
            store.save(book.put(episode))
        } catch (_: Exception) {
            cancelIntent("snooze", episode.id, next)
            event("snooze_registration_failed")
            return false
        }
        event("snoozed:remaining=${episode.snoozesLeft}")
        changed()
        return true
    }

    fun complete(episodeId: String) {
        val book = store.load()
        if (book.active?.id != episodeId) return
        store.save(book.copy(episodes = book.episodes.filterNot { it.id == episodeId }))
        event("challenge_completed")
        changed()
    }

    fun expireTest(episodeId: String) {
        val book = store.load()
        if (book.active?.takeIf { it.isTest }?.id != episodeId) return
        store.save(book.copy(episodes = book.episodes.filterNot { it.id == episodeId }))
        event("test_timeout")
        changed()
    }

    fun scheduleTest(id: String, at: Long, intervalSeconds: Long) {
        check(debug && id == TEST_ALARM_ID) { "test_alarm_unavailable" }
        require(at > System.currentTimeMillis() && (intervalSeconds == 0L || intervalSeconds in 60..86_400))
        check(exactAllowed()) { "exact_permission_denied" }
        check(notificationsAllowed()) { "notification_permission_denied" }
        val book = store.load()
        arm("test", TEST_ALARM_ID, at)
        try {
            store.save(book.copy(test = TestAlarm(at, intervalSeconds)))
        } catch (failure: Exception) {
            cancelIntent("test", TEST_ALARM_ID, at)
            throw failure
        }
        book.test?.let { if (it.at != at) cancelIntent("test", TEST_ALARM_ID, it.at) }
        event("test_scheduled:$at")
        changed()
    }

    fun cancelTest() {
        check(debug) { "test_alarm_unavailable" }
        val book = store.load()
        store.save(book.copy(test = null, episodes = book.episodes.filterNot { it.isTest }))
        book.test?.let { cancelIntent("test", TEST_ALARM_ID, it.at) }
        AlarmService.current?.refresh()
        event("test_cancelled")
        changed()
    }

    private fun fireTest(book: AlarmBook, at: Long, now: Long): Boolean {
        val test = book.test?.takeIf { debug && it.at == at } ?: return false
        val allowed = blocked() == null
        val next = if (allowed && test.intervalSeconds > 0) test.copy(at = nextTestTime(test, now)) else null
        val episodes = if (allowed) book.episodes + AlarmEpisode(
            UUID.randomUUID().toString(), TEST_ALARM_ID, "Bimbi test alarm",
            WakeChallenge.MATH, WakeDifficulty.EASY, arrivedAt = now, scheduledAt = at,
        ) else book.episodes
        store.save(book.copy(test = next, episodes = episodes))
        next?.let { runCatching { arm("test", TEST_ALARM_ID, it.at) } }
        return allowed
    }

    private fun nextTestTime(test: TestAlarm, now: Long): Long {
        val interval = test.intervalSeconds * 1_000
        return test.at + ((now - test.at).coerceAtLeast(0) / interval + 1) * interval
    }

    companion object {
        const val CHANNEL = "bimbi_alarm"
        const val CHANGED = "com.bimbi.app.ALARMS_CHANGED"
        const val FIRE = "com.bimbi.app.FIRE_ALARM"

        fun channels(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            val alarms = NotificationChannel(CHANNEL, "Wake alarms", NotificationManager.IMPORTANCE_HIGH)
            alarms.setSound(null, null)
            alarms.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            manager.createNotificationChannel(alarms)
            manager.createNotificationChannel(NotificationChannel("bimbi_messages", "Bimbi messages", NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmEngine.FIRE) return
        val parts = intent.data?.pathSegments ?: return
        if (parts.size != 3) return
        val at = parts[2].toLongOrNull() ?: return
        val engine = AlarmEngine(context)
        if (runCatching { engine.fire(parts[0], parts[1], at) }.getOrElse {
            engine.event("receiver_failed")
            false
        }) AlarmService.start(context)
    }
}

class RestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val engine = AlarmEngine(context)
        runCatching {
            engine.restore(
                recomputeTime = intent.action == Intent.ACTION_TIME_CHANGED || intent.action == Intent.ACTION_TIMEZONE_CHANGED,
                afterBoot = intent.action == Intent.ACTION_BOOT_COMPLETED,
                forceRearm = intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
                    intent.action == AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            )
        }.onFailure { engine.event("restore_failed") }
    }
}
