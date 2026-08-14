pragma Singleton

import QtQuick
import Quickshell
import "root:/"

/*
 * The island's state machine.
 *
 * Services never set the visible state directly — they *request* one for a
 * duration. This object resolves competing requests by the priority table in
 * Config and falls back to "idle" when nothing is active.
 *
 * Why requests rather than assignment: these events genuinely overlap. Music
 * starts, you nudge the volume, a notification lands, you switch workspace —
 * all inside two seconds. With direct assignment the last writer wins and the
 * notification gets eaten by a workspace change. Here the notification
 * outranks the workspace switch, shows for its full duration, and the island
 * then falls back to whatever is *still* active underneath rather than
 * snapping to idle.
 *
 * Expiry is driven by one Timer armed to the next deadline, not a polling
 * tick — an idle island schedules nothing at all.
 */
Singleton {
    id: root

    /// The state that should currently be on screen.
    property string current: "idle"
    /// Data belonging to `current` (the Notification object, clipboard text…).
    property var payload: null

    /// Previous state, useful for choosing a transition direction.
    property string previous: "idle"

    /// state name -> { until: epoch-ms (0 == sticky), payload: any }
    property var _active: ({})

    signal stateEntered(string state)
    signal stateLeft(string state)

    // ─────────────────────────────────────────────────────────────────────

    /// Show `state` for `duration` ms. duration <= 0 pins it until cleared.
    function request(state, duration, data) {
        if (!state)
            return;
        _active[state] = {
            until: (duration && duration > 0) ? Date.now() + duration : 0,
            payload: data === undefined ? null : data
        };
        _recompute();
    }

    /// Push the expiry of an already-active state further out without
    /// disturbing its payload. Used for "keep showing media while it plays".
    function refresh(state, duration) {
        if (!_active.hasOwnProperty(state)) {
            request(state, duration, null);
            return;
        }
        _active[state].until = (duration && duration > 0) ? Date.now() + duration : 0;
        _recompute();
    }

    function clear(state) {
        if (_active.hasOwnProperty(state)) {
            delete _active[state];
            _recompute();
        }
    }

    function clearAll() {
        _active = ({});
        _recompute();
    }

    function isActive(state) {
        return _active.hasOwnProperty(state);
    }

    /// True when the island is showing anything other than the resting notch.
    readonly property bool expanded: current !== "idle"

    // ─────────────────────────────────────────────────────────────────────

    function _priorityOf(state) {
        const p = Config.priority[state];
        return p === undefined ? 0 : p;
    }

    function _recompute() {
        const now = Date.now();
        let best = null;
        let bestPriority = -1;
        let nextExpiry = 0;

        for (const key in _active) {
            const entry = _active[key];

            // Drop anything that has timed out.
            if (entry.until !== 0 && entry.until <= now) {
                delete _active[key];
                continue;
            }

            const p = _priorityOf(key);
            if (p > bestPriority) {
                bestPriority = p;
                best = key;
            }
            if (entry.until !== 0 && (nextExpiry === 0 || entry.until < nextExpiry))
                nextExpiry = entry.until;
        }

        // Arm a single timer for the soonest deadline.
        if (nextExpiry > 0) {
            expiry.interval = Math.max(16, nextExpiry - now);
            expiry.restart();
        } else {
            expiry.stop();
        }

        const next = best === null ? "idle" : best;
        payload = best === null ? null : _active[best].payload;

        if (next !== current) {
            const old = current;
            previous = old;
            current = next;
            if (Config.debug)
                console.log("[island] state:", old, "->", next);
            stateLeft(old);
            stateEntered(next);
        }
    }

    Timer {
        id: expiry
        repeat: false
        onTriggered: root._recompute()
    }
}
