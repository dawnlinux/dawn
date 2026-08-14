pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Which wallpaper the login screen shows.
 *
 * The greeter has a problem the island does not: under greetd it runs as the
 * unprivileged `greeter` user, which cannot read your home directory and has no
 * awww daemon to ask. So the path is resolved down a chain, most-live first:
 *
 *   1. `awww query` — correct and current, but only works where a daemon is
 *      already running. That is the demo case, inside your own session.
 *   2. The pointer file — a plain text file holding one path, written by the
 *      island whenever you pick a wallpaper. This is the greetd case: put it
 *      somewhere the greeter user can read and the login screen follows your
 *      desktop without ever reading your home.
 *   3. Nothing — the aurora draws instead, so a greeter with no readable
 *      wallpaper is still a greeter and not a black screen.
 *
 * A missing wallpaper must never be fatal. This runs before you can log in to
 * fix it.
 */
Singleton {
    id: root

    /// Pointer files, in order of preference. The first one holding a path to
    /// a readable file wins.
    ///
    /// `/var/lib/dawn/wallpaper` is the one dawn-island actually writes —
    /// `Config.wallpaperPointer`. This file used to name `/etc/greetd/dawn-
    /// wallpaper` instead, which nothing has ever written, so under greetd the
    /// chain always fell through to the aurora and the wallpaper you picked
    /// never reached the login screen. The greetd path is kept as a second
    /// candidate for anyone who would rather put it there.
    property var pointerFiles: [
        "/var/lib/dawn/wallpaper",
        "/etc/greetd/dawn-wallpaper"
    ]

    /// Absolute path, or "" when there is nothing to show.
    property string path: ""

    readonly property bool available: path !== ""
    readonly property url source: available ? "file://" + path : ""

    // One shell, not three. The old chain spawned `awww query`, waited for it
    // to finish, spawned a `head`, waited, then spawned a `test` — three
    // process round-trips in series before the wallpaper could even begin
    // decoding, on the one screen where time to first paint is the whole
    // point. The resolution is a single script now: it prints the first
    // readable candidate and exits.
    //
    // Order matters and is unchanged: the live daemon first because it is
    // correct and current, then the pointer files.
    Process {
        id: resolve
        running: true
        command: ["sh", "-c", `
            emit() { [ -n "$1" ] && [ -r "$1" ] && { printf '%s' "$1"; exit 0; }; return 0; }
            emit "$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -1)"
            for f in ${root.pointerFiles.map(f => `'${f}'`).join(" ")}; do
                emit "$(head -1 "$f" 2>/dev/null)"
            done
            exit 0
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                // Anything that got here was already proven readable by the
                // script — a stale pointer to a deleted wallpaper falls
                // through to the aurora rather than leaving a broken Image on
                // screen.
                if (p !== "")
                    root.path = p;
                else
                    console.log("[dawn-greet] no readable wallpaper; drawing the aurora");
            }
        }
    }
}
