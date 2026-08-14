pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

/*
 * Session actions — lock, sleep, log out, restart, shut down.
 *
 * Named Session rather than Power because Power already means the battery, and
 * two singletons called the same thing is a bug waiting for a tired evening.
 *
 * Two things here are load-bearing:
 *
 *  1. **The destructive actions confirm.** This panel takes exclusive keyboard
 *     focus, and a stray Enter arriving a moment after it opens must not power
 *     the machine off. Lock and sleep are reversible in a keypress, so they
 *     fire immediately; log out, restart and shut down arm first and run on the
 *     second Enter, disarming themselves after a few seconds. The asymmetry is
 *     the point — confirmation everywhere trains you to dismiss it.
 *
 *  2. **Log out goes through uwsm.** This session is started by SDDM as
 *     `uwsm start -e -D Hyprland`, so the compositor is a systemd user unit
 *     (`wayland-wm@hyprland.desktop.service`). Killing Hyprland directly leaves
 *     that unit and its bound session half-alive; `uwsm stop` is the wind-down
 *     the session manager is expecting.
 *
 * Hibernate is deliberately absent: it needs swap at least the size of RAM and
 * a `resume=` kernel parameter, and this machine has neither. Offering it would
 * mean a suspend that never comes back.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enablePower

    property bool open: false
    property int selected: 0

    /// The destructive action currently awaiting its second Enter, or "".
    property string armed: ""

    // ── What this machine can actually do ─────────────────────────────────
    //
    // Locking needs a locker, and there may not be one. Probed once rather
    // than assumed, so the tile appears the day hyprlock is installed and
    // never sits there doing nothing before that.

    property bool lockerAvailable: false

    Process {
        id: probeLocker
        command: ["sh", "-c",
                  "command -v hyprlock || command -v swaylock || command -v gtklock"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.lockerAvailable = text.trim() !== ""
        }
    }

    Component.onCompleted: if (enabled) probeLocker.running = true

    readonly property var actions: {
        const out = [];
        if (lockerAvailable)
            out.push("lock");
        out.push("sleep");
        out.push("logout");
        out.push("restart");
        out.push("shutdown");
        return out;
    }

    readonly property int count: actions.length
    readonly property string current:
        (selected >= 0 && selected < count) ? actions[selected] : ""

    onCountChanged: if (selected >= count) selected = Math.max(0, count - 1)

    // ── Per-action detail ─────────────────────────────────────────────────

    function labelOf(action) {
        switch (action) {
        case "lock":     return "Lock";
        case "sleep":    return "Sleep";
        case "logout":   return "Log Out";
        case "restart":  return "Restart";
        case "shutdown": return "Shut Down";
        }
        return "";
    }

    function iconOf(action) {
        switch (action) {
        case "lock":     return "lock";
        case "sleep":    return "moon";
        case "logout":   return "logout";
        case "restart":  return "restart";
        case "shutdown": return "power";
        }
        return "dot";
    }

    function captionOf(action) {
        switch (action) {
        case "lock":     return "Lock the screen";
        case "sleep":    return "Suspend to RAM";
        case "logout":   return "End the session";
        case "restart":  return "Reboot now";
        case "shutdown": return "Power off";
        }
        return "";
    }

    function commandOf(action) {
        switch (action) {
        case "lock":     return Config.lockCommand;
        case "sleep":    return Config.sleepCommand;
        case "logout":   return Config.logoutCommand;
        case "restart":  return Config.restartCommand;
        case "shutdown": return Config.shutdownCommand;
        }
        return "";
    }

    /// Anything you cannot undo with one keypress.
    function isDestructive(action) {
        return action === "logout" || action === "restart" || action === "shutdown";
    }

    readonly property bool currentIsDestructive: isDestructive(current)
    readonly property bool currentIsArmed: armed !== "" && armed === current

    // ── The panel ─────────────────────────────────────────────────────────

    function show() {
        if (!enabled)
            return;
        // Always opens on the least destructive thing on offer, never on
        // Shut Down. Where the selection starts is a safety property.
        selected = 0;
        armed = "";
        open = true;
        IslandState.request("power", 0);   // 0 == sticky, no timeout
    }

    function hide() {
        open = false;
        armed = "";
        selected = 0;
        IslandState.clear("power");
    }

    function toggle() {
        if (open) hide(); else show();
    }

    function move(delta) {
        if (count === 0)
            return;
        // Moving off an armed tile disarms it: the confirmation belongs to the
        // action you were looking at, not to the next Enter you happen to press.
        armed = "";
        selected = (selected + delta % count + count) % count;
    }

    Timer {
        id: disarm
        interval: Config.powerConfirmTimeout
        onTriggered: root.armed = ""
    }

    /// Enter. Harmless actions run; destructive ones arm, then run.
    function activate(indexOrUndefined) {
        const i = indexOrUndefined === undefined ? selected : indexOrUndefined;
        if (i < 0 || i >= count)
            return;
        const action = actions[i];
        selected = i;

        if (isDestructive(action) && armed !== action) {
            armed = action;
            disarm.restart();
            return;
        }

        disarm.stop();
        armed = "";
        run(action);
    }

    function run(action) {
        const cmd = commandOf(action);
        if (!cmd)
            return;
        // Close first: the panel should not still be on screen during the
        // second or two it takes the compositor to go away.
        hide();
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
}
