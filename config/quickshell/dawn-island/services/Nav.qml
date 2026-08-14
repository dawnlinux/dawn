pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.services

/*
 * Keyboard driving for the island.
 *
 * The island started out as a pointer surface: you hover it to expand, click to
 * pin, scroll to change the volume. That is fine until your hands are on the
 * keyboard, which on a tiling desktop is nearly always — reaching for the mouse
 * to find out whether the headphones are still connected is exactly the
 * interruption the island exists to avoid.
 *
 * So this is the second way in. A global shortcut opens a status panel, arrow
 * keys walk it, Enter toggles the selected radio, Left/Right slide the ones
 * that hold a level, Escape puts it away. The panel is a *state* like any
 * other, which is why it morphs out of the notch instead of appearing beside
 * it, and why the priority table decides what happens when a notification
 * lands mid-navigation.
 *
 * The row list is computed from what the machine actually has. A desktop with
 * no battery and no bluetooth adapter gets a two-row panel, not a list of
 * dashes — the panel never shows a control that cannot do anything.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableStatusPanel

    property bool open: false
    property int selected: 0

    readonly property var rows: {
        const out = [];
        if (Config.enableNetwork && Net.enabled)              out.push("network");
        if (Config.enableBluetooth && Bt.available)           out.push("bluetooth");
        if (Config.enableBattery && Power.available)          out.push("battery");
        if (Audio.ready)                                      out.push("volume");
        if (Config.enableBrightness && Brightness.available)  out.push("brightness");
        return out;
    }

    readonly property int count: rows.length
    readonly property string currentRow:
        (selected >= 0 && selected < count) ? rows[selected] : ""

    /// Keep the highlight inside the list when a row disappears underneath it —
    /// unplugging a bluetooth adapter should not leave the selection nowhere.
    onRowsChanged: if (selected >= count) selected = Math.max(0, count - 1)

    // ── The panel ─────────────────────────────────────────────────────────

    function show() {
        if (!enabled || count === 0)
            return;
        selected = 0;
        open = true;
        IslandState.request("status", 0);   // 0 == sticky, no timeout
    }

    function hide() {
        open = false;
        selected = 0;
        IslandState.clear("status");
    }

    function toggle() {
        if (open) hide(); else show();
    }

    function move(delta) {
        if (count === 0)
            return;
        // Wraps, so holding Down cycles rather than sticking at the bottom.
        selected = (selected + delta % count + count) % count;
    }

    // ── Row actions ───────────────────────────────────────────────────────
    //
    // Three verbs, deliberately separated:
    //
    //   Enter      open the real tool for this row
    //   Backspace  switch it off
    //   Ctrl       switch it back on
    //
    // Enter used to toggle, which was the wrong verb for the wrong reason: the
    // key you press most often should do the thing you most often want, and on
    // a wifi row that is "show me the networks", not "cut my connection". Off
    // and on get their own keys, so neither can be hit by muscle memory aimed
    // at the other — and unlike a toggle, both are idempotent: mashing
    // Backspace leaves the radio off rather than flapping it.

    /// Rows that open something on Enter.
    function isLaunch(row) {
        return row === "network" || row === "bluetooth";
    }

    /// Rows Backspace / Ctrl can switch off and on.
    function isSwitch(row) {
        return row === "network" || row === "bluetooth" || row === "volume";
    }

    /// Rows Left/Right can slide.
    function isLevel(row) {
        return row === "volume" || row === "brightness";
    }

    readonly property bool currentIsLaunch: isLaunch(currentRow)
    readonly property bool currentIsSwitch: isSwitch(currentRow)
    readonly property bool currentIsLevel: isLevel(currentRow)

    function _run(command) {
        if (command !== "")
            Quickshell.execDetached(["sh", "-c", command]);
    }

    /// Enter. Hands off to the tool that can actually do the job — picking a
    /// network or pairing a device needs a scan and a password prompt, which
    /// is more than a notch should ever try to be. The panel gets out of the
    /// way first; the terminal is about to take the focus anyway.
    function activate() {
        switch (currentRow) {
        case "network":
            hide();
            _run(Config.wifiCommand);
            break;
        case "bluetooth":
            hide();
            _run(Config.bluetoothCommand);
            break;
        case "volume":
            Audio.toggleMute();
            break;
        }
    }

    /// Backspace / Ctrl. A row with no switch ignores both rather than closing
    /// the panel out from under you.
    function setEnabled(on) {
        switch (currentRow) {
        case "network":   Net.setWifi(on);     break;
        case "bluetooth": Bt.setPowered(on);   break;
        case "volume":    Audio.setMuted(!on); break;
        }
    }

    /// Left / Right, as -1 / +1.
    function adjust(direction) {
        switch (currentRow) {
        case "volume":
            Audio.step(direction * Config.volumeKeyStep);
            break;
        case "brightness":
            Brightness.step(direction * Config.brightnessKeyStep);
            break;
        }
    }

    // ── The expanded panel, from the keyboard ─────────────────────────────
    //
    // The keyboard equivalent of parking the pointer on the notch. Kept here
    // rather than on the island itself because the island is instantiated per
    // monitor and this has to mean the same thing on all of them.

    property bool panelPinned: false

    function togglePanel() {
        panelPinned = !panelPinned;
    }

    function closeAll() {
        panelPinned = false;
        if (open)
            hide();
    }
}
