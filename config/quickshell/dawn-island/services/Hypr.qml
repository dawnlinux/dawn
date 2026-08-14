pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

/*
 * Hyprland state.
 *
 * Everything here is event-driven off Hyprland's IPC socket, which Quickshell
 * already maintains — there is no hyprctl polling anywhere in this shell.
 */
Singleton {
    id: root

    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property var activeWindow: Hyprland.activeToplevel

    readonly property int workspaceId: focusedWorkspace ? focusedWorkspace.id : 0
    readonly property string workspaceName: focusedWorkspace ? (focusedWorkspace.name || "") : ""
    readonly property bool hasFullscreen: focusedWorkspace ? focusedWorkspace.hasFullscreen : false

    /// Special workspaces (scratchpads) have negative ids in Hyprland.
    readonly property bool isSpecial: workspaceId < 0

    readonly property string windowTitle: activeWindow ? (activeWindow.title || "") : ""

    readonly property var workspaces: Hyprland.workspaces ? Hyprland.workspaces.values : []

    /// Occupied workspace ids, sorted — used by the workspace indicator.
    readonly property var occupied: {
        const out = [];
        for (const w of workspaces) {
            if (!w || w.id < 0)
                continue;
            const hasWindows = w.toplevels && w.toplevels.values.length > 0;
            if (hasWindows || w.id === root.workspaceId)
                out.push(w.id);
        }
        return out.sort((a, b) => a - b);
    }

    readonly property string monitorName: focusedMonitor ? focusedMonitor.name : ""

    signal workspaceSwitched(int id, string name)

    /*
     * Hyprland 0.56 replaced the string dispatcher grammar with a Lua API:
     * the IPC now wraps whatever you send in `return hl.dispatch(...)`, so the
     * old `dispatch workspace 3` is a syntax error rather than a no-op — it
     * fails silently from QML's point of view, which is exactly the kind of
     * breakage that is invisible until someone clicks the thing.
     *
     * Verified against the running compositor on this machine:
     *   0.56+  → dispatch hl.dsp.focus({workspace="3"})
     *   older  → dispatch workspace 3
     *
     * Config.hyprlandLuaDispatch selects the grammar.
     */
    function dispatch(request) {
        Hyprland.dispatch(request);
    }

    function gotoWorkspace(id) {
        if (Config.hyprlandLuaDispatch)
            Hyprland.dispatch('hl.dsp.focus({workspace="' + id + '"})');
        else
            Hyprland.dispatch("workspace " + id);
    }

    /// Which Hyprland monitor corresponds to a Quickshell screen.
    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }

    // ── Change detection ──────────────────────────────────────────────────

    property bool _settled: false
    property int _lastWorkspace: -9999

    Timer {
        interval: 600
        running: true
        onTriggered: {
            root._lastWorkspace = root.workspaceId;
            root._settled = true;
        }
    }

    onWorkspaceIdChanged: {
        if (!_settled || workspaceId === _lastWorkspace)
            return;
        _lastWorkspace = workspaceId;
        workspaceSwitched(workspaceId, workspaceName);
    }

    // ── Keyboard layout ───────────────────────────────────────────────────
    // Hyprland only reports layout switches as raw events, so this listens to
    // the event stream rather than a property.

    property string keyboardLayout: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                // data is "keyboard-name,Layout Name"
                const parts = event.data.split(",");
                if (parts.length >= 2)
                    root.keyboardLayout = parts[parts.length - 1];
            }
        }
    }
}
