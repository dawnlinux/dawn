pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

/*
 * Clipboard events.
 *
 * NOT Quickshell.clipboardText, which was the obvious choice and does not work
 * here: on Wayland the compositor only sends selection offers to the client
 * holding keyboard focus, and a layer-shell panel deliberately has none. The
 * property simply never changes, silently. This is exactly why wl-clipboard
 * exists as a daemon — wl-paste uses the data-control protocol, which is
 * focus-independent.
 *
 * So one long-lived `wl-paste --watch` supplies the events. The helper flattens
 * each selection to a single line and caps it, so what arrives here is already
 * the size of a preview rather than a whole file.
 *
 * Sanitisation is deliberately conservative: anything that pattern-matches as a
 * credential is shown as a redacted chip rather than previewed, because this
 * text renders full width on a screen that may well be shared or recorded.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableClipboard

    property string current: ""
    property bool sensitive: false
    property string preview: ""

    signal copied(string preview, bool sensitive)

    /// wl-paste emits the *existing* selection the moment it starts. That one
    /// is whatever was already on the clipboard before the shell launched, and
    /// announcing it would pop the island open on every login.
    property bool _primed: false

    function _looksSensitive(text) {
        if (!Config.sanitizeClipboard)
            return false;
        for (const pattern of Config.clipboardSecretPatterns) {
            try {
                if (new RegExp(pattern, "i").test(text))
                    return true;
            } catch (e) {
                // A bad user-supplied regex must not take the shell down.
                if (Config.debug)
                    console.warn("[clipboard] bad pattern:", pattern, e);
            }
        }
        // A long unbroken high-entropy-looking blob is probably a key.
        if (/^[A-Za-z0-9+\/=_\-]{40,}$/.test(text.trim()))
            return true;
        return false;
    }

    function _makePreview(text) {
        const clean = text.replace(/\s+/g, " ").trim();
        if (clean.length <= Config.clipboardPreviewLength)
            return clean;
        // Not String.trimEnd(): Qt's JS engine does not implement it, and
        // calling it throws mid-binding, which shows up as text that silently
        // never appears rather than as an obvious failure.
        return clean.slice(0, Config.clipboardPreviewLength).replace(/\s+$/, "") + "…";
    }

    function _handle(text) {
        if (!root.enabled || text === "" || text === root.current)
            return;

        root.current = text;

        if (!root._primed) {
            root._primed = true;
            return;
        }

        root.sensitive = root._looksSensitive(text);
        root.preview = root.sensitive ? "" : root._makePreview(text);
        root.copied(root.preview, root.sensitive);
    }

    // ── Event source ──────────────────────────────────────────────────────
    //
    // The helper truncates before anything crosses the pipe (a copied 40MB log
    // should not become a 40MB QString) and flattens newlines so each
    // selection is exactly one line for SplitParser to find.

    Process {
        id: watcher
        running: root.enabled
        command: ["wl-paste", "--type", "text", "--watch",
                  "sh", "-c", "head -c 2048 | tr '\\n\\r' '  '; echo"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) { root._handle(line); }
        }
    }

    /// Opens the cliphist picker.
    function openPicker() {
        if (Config.clipboardPickerCommand !== "")
            Quickshell.execDetached(["sh", "-c", Config.clipboardPickerCommand]);
    }

    // ── cliphist history daemon ───────────────────────────────────────────
    // The watcher above sees the *current* selection only. Without this,
    // `cliphist list` stays empty and the picker is useless.

    Process {
        id: historyDaemonCheck
        running: root.enabled && Config.startClipboardDaemon
        command: ["sh", "-c", "pgrep -f 'wl-paste.*cliphist store' >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "no") {
                    Quickshell.execDetached(["sh", "-c",
                        "wl-paste --type text --watch cliphist store &"]);
                    if (Config.debug)
                        console.log("[clipboard] started cliphist store watcher");
                }
            }
        }
    }
}
