pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

/*
 * Notification daemon.
 *
 * IMPORTANT: this claims org.freedesktop.Notifications on the session bus.
 * Only one process can own that name, so swaync / dunst / mako must not be
 * running or this silently receives nothing (the other daemon keeps the name
 * and Quickshell just never gets called). See README for the handover.
 *
 * Notifications are retained (`tracked`) so the centre can show recent history,
 * but the list is capped — an uncapped list is a slow memory leak on a machine
 * that runs for weeks.
 *
 * Entries are `{ n, at }` rather than bare Notification objects because the
 * freedesktop spec carries no arrival time and "Signal · 4m" is most of what
 * makes a history list readable. The wrapper is the only place to keep it.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableNotifications

    /// Most recent first. Each entry is { n: Notification, at: epoch-ms }.
    property var recent: []
    property int maxRecent: 12

    readonly property var latest: recent.length > 0 ? recent[0].n : null
    readonly property int count: recent.length

    /// Do not disturb. Notifications are still *recorded* — they simply stop
    /// interrupting. Silencing something by throwing it away is how you miss
    /// the one that mattered, so the centre still lists everything.
    property bool dnd: false

    signal arrived(var notification)

    function _blacklisted(n) {
        const app = (n.appName || "").toLowerCase();
        for (const bad of Config.notificationBlacklist) {
            if (bad && app.indexOf(bad.toLowerCase()) !== -1)
                return true;
        }
        return false;
    }

    function dismiss(n) {
        if (!n)
            return;
        const idx = recent.findIndex(e => e.n === n);
        if (idx !== -1) {
            const copy = recent.slice();
            copy.splice(idx, 1);
            recent = copy;
            // Keep the highlight on a real row as the list shortens under it.
            if (selected >= copy.length)
                selected = Math.max(0, copy.length - 1);
        }
        if (n.tracked)
            n.tracked = false;
    }

    function clearAll() {
        for (const e of recent) {
            if (e && e.n && e.n.tracked)
                e.n.tracked = false;
        }
        recent = [];
        selected = 0;
    }

    /// Compact relative age: the centre is a glance, not a log viewer.
    function since(at) {
        const s = Math.max(0, Math.floor((Date.now() - at) / 1000));
        if (s < 45)    return "now";
        if (s < 3600)  return Math.round(s / 60) + "m";
        if (s < 86400) return Math.round(s / 3600) + "h";
        return Math.round(s / 86400) + "d";
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        inlineReplySupported: false

        onNotification: function (notification) {
            if (!root.enabled)
                return;
            if (root._blacklisted(notification))
                return;

            // Retain it so it survives past the daemon callback and can be
            // shown in the history panel.
            notification.tracked = true;

            const copy = root.recent.slice();
            copy.unshift({ n: notification, at: Date.now() });
            while (copy.length > root.maxRecent) {
                const dropped = copy.pop();
                if (dropped && dropped.n && dropped.n.tracked)
                    dropped.n.tracked = false;
            }
            root.recent = copy;

            // While the centre is open the selection is an index into this
            // list, and unshifting would silently move it onto a new arrival.
            if (root.open && root.selected > 0)
                root.selected += 1;

            // Do-not-disturb suppresses the interruption, not the record —
            // except for Critical, which is what that urgency level is *for*:
            // a low-battery or a disk-full does not respect your quiet hours.
            if (root.dnd && notification.urgency !== NotificationUrgency.Critical)
                return;

            root.arrived(notification);
        }
    }

    // ── The notification centre ───────────────────────────────────────────
    //
    // Panel state lives on the service, the same way Launcher and Wallpaper
    // own theirs: the thing that holds the list is the thing that knows which
    // row is selected, and splitting those across two files means every
    // dismissal has to reconcile them.

    property bool open: false
    property int selected: 0

    readonly property var current:
        (selected >= 0 && selected < count) ? recent[selected] : null

    function show() {
        if (!Config.enableNotifCenter)
            return;
        selected = 0;
        open = true;
        IslandState.request("notifcenter", 0);   // 0 == sticky, no timeout
    }

    function hide() {
        open = false;
        selected = 0;
        IslandState.clear("notifcenter");
    }

    function toggle() {
        if (open) hide(); else show();
    }

    function move(delta) {
        if (count === 0)
            return;
        selected = (selected + delta % count + count) % count;
    }

    /// Enter — run the notification's default action, then dismiss it. An
    /// action is the reason the notification was worth showing at all.
    function invokeSelected() {
        const e = current;
        if (!e || !e.n)
            return;
        const acts = e.n.actions;
        if (acts && acts.length > 0) {
            const preferred = acts.find(a => a.identifier === "default") || acts[0];
            if (preferred)
                preferred.invoke();
        }
        dismiss(e.n);
        if (count === 0)
            hide();
    }

    /// Backspace — the same "switch it off" verb the status panel uses.
    function dismissSelected() {
        const e = current;
        if (!e)
            return;
        dismiss(e.n);
        if (count === 0)
            hide();
    }

    function toggleDnd() {
        dnd = !dnd;
    }

    /// Truncation that avoids cutting mid-word where it can.
    function truncate(text, limit) {
        if (!text)
            return "";
        const clean = text.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
        if (clean.length <= limit)
            return clean;
        const cut = clean.slice(0, limit);
        const lastSpace = cut.lastIndexOf(" ");
        const kept = lastSpace > limit * 0.6 ? cut.slice(0, lastSpace) : cut;
        // Not String.trimEnd(): Qt's JS engine does not implement it, and the
        // throw happens inside a binding, so the only symptom is text that
        // never renders.
        return kept.replace(/\s+$/, "") + "…";
    }
}
