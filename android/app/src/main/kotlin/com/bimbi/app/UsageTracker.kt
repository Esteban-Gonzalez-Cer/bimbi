package com.bimbi.app

/**
 * Folds Usage Access activity events into foreground time per app.
 *
 * An app counts as in use while at least one of its activities is resumed, so
 * moving between two screens of the same app is one continuous stretch. An app
 * already open when counting starts (its first event is a pause) is counted from
 * [start]. Pure and clock-free so it can be unit-tested.
 */
internal class UsageTracker(start: Long) {
    var start = start
        private set

    /** Time of the last event applied; the next query starts after it. */
    var cursor = start
        private set

    private val totals = HashMap<String, Long>()
    private val since = HashMap<String, Long>()
    private val open = HashMap<String, MutableSet<String>>()
    private val seen = HashSet<String>()
    private var foreground: String? = null

    fun resumed(pkg: String, component: String, at: Long) {
        advance(at)
        seen += pkg
        val components = open.getOrPut(pkg) { mutableSetOf() }
        if (components.isEmpty()) since[pkg] = at
        components += component
        foreground = pkg
    }

    fun paused(pkg: String, component: String, at: Long) {
        advance(at)
        val components = open[pkg]
        if (components == null) {
            if (seen.add(pkg)) add(pkg, at - start)
            return
        }
        if (components.remove(component) && components.isEmpty()) {
            open.remove(pkg)
            add(pkg, at - (since.remove(pkg) ?: at))
            if (foreground == pkg) foreground = null
        }
    }

    /** Starts a new day at [dayStart]; apps still open keep counting from it. */
    fun rollOver(dayStart: Long) {
        totals.clear()
        seen.clear()
        seen += open.keys
        for (pkg in open.keys) since[pkg] = dayStart
        start = dayStart
        cursor = maxOf(cursor, dayStart)
    }

    /** The app most recently brought to the front that is still open. */
    fun foreground(): String? = foreground?.takeIf { open[it]?.isNotEmpty() == true }

    /** Foreground milliseconds per app since [start], including open stretches. */
    fun usage(now: Long): Map<String, Long> {
        val result = HashMap(totals)
        for ((pkg, from) in since) {
            if (open[pkg]?.isNotEmpty() == true) result[pkg] = (result[pkg] ?: 0L) + (now - from).coerceAtLeast(0)
        }
        return result
    }

    private fun add(pkg: String, ms: Long) {
        if (ms > 0) totals[pkg] = (totals[pkg] ?: 0L) + ms
    }

    private fun advance(at: Long) {
        if (at > cursor) cursor = at
    }
}

/** What the person chose to pause. Stored only on this device. */
internal data class GuardRules(
    val focusApps: Set<String> = emptySet(),
    val limits: Map<String, Int> = emptyMap(),
    val focusUntil: Long? = null,
) {
    fun focusActive(now: Long) = focusUntil != null && now < focusUntil && focusApps.isNotEmpty()

    /** The service only runs while there is something to enforce. */
    fun hasWork(now: Long) = focusActive(now) || limits.isNotEmpty()
}

internal sealed interface Shield {
    data class Focus(val until: Long) : Shield
    data class Limit(val usedMs: Long, val limitMinutes: Int) : Shield
}

/**
 * Decides whether [pkg] in the foreground must be covered. Exempt apps
 * (Bimbi, the launcher, Settings, the dialer, the keyboard) are never covered,
 * so the person can always reach Android settings and emergency calls.
 */
internal fun shieldFor(
    pkg: String?,
    rules: GuardRules,
    usage: Map<String, Long>,
    now: Long,
    exempt: (String) -> Boolean,
): Shield? {
    if (pkg == null || exempt(pkg)) return null
    if (rules.focusActive(now) && pkg in rules.focusApps) return Shield.Focus(requireNotNull(rules.focusUntil))
    val limit = rules.limits[pkg] ?: return null
    val used = usage[pkg] ?: 0L
    return if (used >= limit * 60_000L) Shield.Limit(used, limit) else null
}
