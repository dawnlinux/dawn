pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

/*
 * The keybind cheatsheet's state and data.
 *
 * The binds are read from `hyprctl -j binds` rather than parsed out of
 * binds.lua. Hyprland already knows what is bound — including anything added
 * in ~/.config/dawn/local.lua — so asking it is the only source that cannot
 * drift from what the keyboard actually does.
 *
 * Only binds carrying a `description` are shown. That is deliberate: a bind
 * without one is either internal plumbing or something the author did not
 * think worth explaining, and a cheatsheet padded with `SUPER + 1 ->
 * workspace 1` twenty times is worse than a short one.
 *
 * Fetched on open rather than kept live. A cheatsheet is consulted for a few
 * seconds every few days; holding a process open to watch for changes to a
 * file that changes when you edit your config would be pure waste.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableKeybinds

    property bool open: false
    property int selected: 0

    /// Every bind with a description, grouped and ready to render.
    property var binds: []

    /// Set while hyprctl is running, so the view can say so rather than
    /// showing an empty list that looks like a bug.
    property bool loading: false

    /// Populated when hyprctl fails, so the view can show why.
    property string error: ""

    // ── Modifier decoding ─────────────────────────────────────────────────
    //
    // Hyprland reports modifiers as a bitmask. The values come from the
    // Wayland/xkb modifier order, which is the same one libinput uses.
    readonly property var _modNames: [
        { bit: 64, name: "Super" },
        { bit: 4,  name: "Ctrl"  },
        { bit: 8,  name: "Alt"   },
        { bit: 1,  name: "Shift" }
    ]

    function _modString(mask) {
        const parts = [];
        for (const m of root._modNames)
            if (mask & m.bit)
                parts.push(m.name);
        return parts;
    }

    /// Turn a key name into something worth reading. Hyprland gives raw xkb
    /// names, which are mostly fine but occasionally shout.
    function _keyName(key) {
        switch (key) {
        case "RETURN":  return "Enter";
        case "SPACE":   return "Space";
        case "ESCAPE":  return "Esc";
        case "SLASH":   return "/";
        case "PERIOD":  return ".";
        case "COMMA":   return ",";
        case "MINUS":   return "-";
        case "EQUAL":   return "=";
        case "mouse:272": return "Click";
        case "mouse:273": return "Right-click";
        case "mouse:274": return "Middle-click";
        case "mouse_up":   return "Wheel up";
        case "mouse_down": return "Wheel down";
        default:
            // XF86AudioRaiseVolume -> Audio Raise Volume
            if (key.startsWith("XF86"))
                return key.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
            return key.length === 1 ? key.toUpperCase() : key;
        }
    }

    Process {
        id: fetch
        command: ["hyprctl", "-j", "binds"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                let parsed;
                try {
                    parsed = JSON.parse(text);
                } catch (e) {
                    root.error = "could not read hyprctl output";
                    root.binds = [];
                    return;
                }

                // Merged by description, not listed per bind.
                //
                // Dawn binds both the arrows and hjkl to the same actions, so a
                // raw listing shows "Focus Down" twice and doubles the length
                // of the sheet. One row per action, carrying every chord that
                // triggers it, is both shorter and more useful — it tells you
                // the alternatives you did not know about.
                const byDescription = {};
                const order = [];
                for (const b of parsed) {
                    const desc = (b.description || "").trim();
                    if (desc === "")
                        continue;

                    const chord = {
                        mods: root._modString(b.modmask),
                        key: root._keyName(b.key || "")
                    };

                    if (byDescription[desc]) {
                        byDescription[desc].chords.push(chord);
                    } else {
                        byDescription[desc] = { description: desc, chords: [chord] };
                        order.push(desc);
                    }
                }

                const out = order.map(d => byDescription[d]);

                // Sorted by description rather than by key: you arrive knowing
                // what you want to do, not which key does it.
                out.sort((a, b) => a.description.localeCompare(b.description));

                root.error = out.length === 0 ? "no binds carry a description" : "";
                root.binds = out;
                root.selected = 0;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    root.loading = false;
                    root.error = text.trim();
                }
            }
        }
    }

    function refresh() {
        if (fetch.running)
            return;
        root.loading = true;
        root.error = "";
        fetch.running = true;
    }

    // ── Navigation ────────────────────────────────────────────────────────

    function move(step) {
        if (root.binds.length === 0)
            return;
        // Clamped rather than wrapping. A long list that jumps from the last
        // entry back to the first loses your place; the launcher wraps because
        // its list is short and filtered.
        root.selected = Math.max(0, Math.min(root.binds.length - 1, root.selected + step));
    }

    function page(step) {
        root.move(step * Config.keybindsPageSize);
    }

    function first() { root.selected = 0; }
    function last()  { root.selected = Math.max(0, root.binds.length - 1); }

    // ── Lifecycle ─────────────────────────────────────────────────────────

    function show() {
        if (!root.enabled)
            return;
        root.open = true;
        root.refresh();
        IslandState.request("keybinds", 0);   // 0 == sticky, no timeout
    }

    function hide() {
        root.open = false;
        IslandState.clear("keybinds");
    }

    function toggle() {
        if (root.open)
            root.hide();
        else
            root.show();
    }
}
