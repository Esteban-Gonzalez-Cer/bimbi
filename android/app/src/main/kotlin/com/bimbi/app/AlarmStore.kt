package com.bimbi.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/** The receiver, service and Flutter bridge all use the same private store. */
internal class AlarmStore(context: Context) {
    private val preferences = context.getSharedPreferences("bimbi_alarm", Context.MODE_PRIVATE)

    fun legacy(): JSONObject? = preferences.getString("pending", null)?.let {
        runCatching { JSONObject(it) }.getOrNull()
    }

    fun load(): AlarmBook {
        val json = preferences.getString("book_v4", null)?.let { JSONObject(it) } ?: return AlarmBook()
        return AlarmBook(
            alarms = json.objects("alarms").map { alarm(it) },
            episodes = json.objects("episodes").map { episode(it) },
            test = json.optJSONObject("test")?.let { TestAlarm(it.getLong("at"), it.getLong("repeat")) },
        )
    }

    fun save(book: AlarmBook, clearLegacy: Boolean = false) {
        val json = JSONObject()
            .put("alarms", JSONArray(book.alarms.map { alarmJson(it) }))
            .put("episodes", JSONArray(book.episodes.map { episodeJson(it) }))
        book.test?.let { json.put("test", JSONObject().put("at", it.at).put("repeat", it.intervalSeconds)) }
        val edit = preferences.edit().putString("book_v4", json.toString())
        if (clearLegacy) edit.remove("pending").remove("active")
        check(edit.commit()) { "alarm_storage_failed" }
    }

    fun lastEvent(): String = preferences.getString("lastEvent", "No alarm event recorded")!!

    fun record(message: String) {
        preferences.edit().putString("lastEvent", message).apply()
    }

    private fun alarm(json: JSONObject): LocalAlarm = LocalAlarm(
        id = json.getString("id"),
        label = json.getString("label"),
        hour = json.getInt("hour"),
        minute = json.getInt("minute"),
        days = json.getJSONArray("days").let { days -> (0 until days.length()).map { days.getInt(it) }.toSet() },
        challenge = WakeChallenge.parse(json.optString("challenge")) ?: WakeChallenge.MATH,
        difficulty = WakeDifficulty.parse(json.optString("difficulty")) ?: WakeDifficulty.NORMAL,
        enabled = json.getBoolean("enabled"),
        onceDay = json.date("once"),
        lastFiredDay = json.date("lastFired"),
        next = json.optJSONObject("next")?.let { AlarmTime(it.getLong("at"), LocalDate.parse(it.getString("day"))) },
        status = AlarmStatus.entries.firstOrNull { it.wire == json.optString("status") } ?: AlarmStatus.OFF,
        sound = json.sound(),
    )

    private fun alarmJson(alarm: LocalAlarm) = JSONObject()
        .put("id", alarm.id).put("label", alarm.label).put("hour", alarm.hour).put("minute", alarm.minute)
        .put("days", JSONArray(alarm.days.sorted()))
        .put("challenge", alarm.challenge.wire).put("difficulty", alarm.difficulty.wire)
        .put("tone", alarm.sound.tone.wire).put("volume", alarm.sound.volume).put("intensity", alarm.sound.intensity.wire)
        .put("enabled", alarm.enabled).put("status", alarm.status.wire)
        .put("once", alarm.onceDay?.toString()).put("lastFired", alarm.lastFiredDay?.toString())
        .put("next", alarm.next?.let { JSONObject().put("at", it.at).put("day", it.day.toString()) })

    private fun episode(json: JSONObject) = AlarmEpisode(
        id = json.getString("id"),
        alarmId = json.getString("alarmId"),
        label = json.getString("label"),
        challenge = WakeChallenge.parse(json.optString("challenge")) ?: WakeChallenge.MATH,
        difficulty = WakeDifficulty.parse(json.optString("difficulty")) ?: WakeDifficulty.NORMAL,
        arrivedAt = json.getLong("arrivedAt"),
        snoozes = json.getInt("snoozes"),
        snooze = json.optJSONObject("snooze")?.let { SnoozeTime(it.getLong("at"), it.getLong("elapsed"), it.getInt("boot")) },
        scheduledAt = json.optLong("scheduledAt", json.getLong("arrivedAt")),
        sound = json.sound(),
    )

    private fun episodeJson(episode: AlarmEpisode) = JSONObject()
        .put("id", episode.id).put("alarmId", episode.alarmId).put("label", episode.label)
        .put("challenge", episode.challenge.wire).put("difficulty", episode.difficulty.wire)
        .put("arrivedAt", episode.arrivedAt).put("snoozes", episode.snoozes)
        .put("scheduledAt", episode.scheduledAt)
        .put("tone", episode.sound.tone.wire).put("volume", episode.sound.volume).put("intensity", episode.sound.intensity.wire)
        .put("snooze", episode.snooze?.let {
            JSONObject().put("at", it.at).put("elapsed", it.elapsed).put("boot", it.boot)
        })

    private fun JSONObject.objects(key: String): List<JSONObject> =
        optJSONArray(key)?.let { values -> (0 until values.length()).map { values.getJSONObject(it) } } ?: emptyList()

    private fun JSONObject.date(key: String): LocalDate? = optString(key).takeIf(String::isNotEmpty)?.let(LocalDate::parse)

    private fun JSONObject.sound() = AlarmSound.from(
        optString("tone"), optInt("volume", 100),
        AlarmIntensity.parse(optString("intensity"), legacyBoost = optBoolean("boost")),
    )
}
