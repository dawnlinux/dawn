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
 * Notifications are retained (`tracked`) so the expanded panel can show recent
 * history, but the list is capped — an uncapped list is a slow memory leak on
 * a machine that runs for weeks.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableNotifications

    /// Most recent first.
    property var recent: []
    property int maxRecent: 12

    readonly property var latest: recent.length > 0 ? recent[0] : null
    readonly property int count: recent.length

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
        const idx = recent.indexOf(n);
        if (idx !== -1) {
            const copy = recent.slice();
            copy.splice(idx, 1);
            recent = copy;
        }
        if (n.tracked)
            n.tracked = false;
    }

    function clearAll() {
        for (const n of recent) {
            if (n && n.tracked)
                n.tracked = false;
        }
        recent = [];
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
            copy.unshift(notification);
            while (copy.length > root.maxRecent) {
                const dropped = copy.pop();
                if (dropped && dropped.tracked)
                    dropped.tracked = false;
            }
            root.recent = copy;

            root.arrived(notification);
        }
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
