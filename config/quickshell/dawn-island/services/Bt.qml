pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs

/*
 * Bluetooth state via Quickshell's BlueZ binding.
 *
 * Named Bt rather than Bluetooth because `Quickshell.Bluetooth` already exports
 * a singleton called Bluetooth, and a service that shadows the thing it wraps is
 * a trap for whoever reads it next.
 *
 * The island only ever cares about two facts: whether the radio is on, and what
 * is actually connected to it. Pairing, discovery and the full device list
 * belong in a settings panel, not in a notch — so this exposes a summary and a
 * power toggle and stops there.
 *
 * `primary` prefers a device that reports a battery level, because headphones
 * running flat is the one bluetooth fact worth putting on screen; a connected
 * mouse that reports nothing can wait behind it.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableBluetooth

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: enabled && adapter !== null

    /// The radio. Write through setPowered() / togglePower().
    readonly property bool powered: available && adapter.enabled

    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedDevices: devices.filter(d => d && d.connected)
    readonly property int connectedCount: connectedDevices.length
    readonly property bool connected: connectedCount > 0

    readonly property var primary: {
        if (connectedCount === 0)
            return null;
        return connectedDevices.find(d => d.batteryAvailable) || connectedDevices[0];
    }

    readonly property string deviceName:
        primary ? (primary.deviceName || primary.name || "Device") : ""

    readonly property bool batteryAvailable: primary !== null && primary.batteryAvailable

    /// BlueZ reports 0..100 here; normalised to 0..1 like every other level in
    /// the shell, with the same guard in case a future version changes units.
    readonly property real batteryFraction: {
        if (!batteryAvailable)
            return 0;
        const b = primary.battery;
        return b > 1.0 ? Math.max(0, Math.min(1, b / 100)) : Math.max(0, Math.min(1, b));
    }
    readonly property int batteryPercent: Math.round(batteryFraction * 100)

    readonly property string label: {
        if (!available)           return "No adapter";
        if (!powered)             return "Bluetooth off";
        if (connectedCount === 0) return "Not connected";
        if (connectedCount === 1) return deviceName;
        return connectedCount + " devices";
    }

    /// Second line: the connected device's battery if it has one, otherwise
    /// enough to disambiguate a multi-device connection.
    readonly property string detail: {
        if (!powered || connectedCount === 0)
            return "";
        if (batteryAvailable)
            return batteryPercent + "%";
        return connectedCount > 1 ? deviceName : "Connected";
    }

    function setPowered(on) {
        if (adapter)
            adapter.enabled = on;
    }

    function togglePower() {
        setPowered(!powered);
    }

    // ── Edge-triggered announcements ──────────────────────────────────────
    //
    // Same shape as Net: let the bus settle, then report only transitions.
    // Without the delay the island announces every device BlueZ already knew
    // about, every time the shell starts.

    signal changed(bool active, string name)

    property bool _settled: false
    property int _lastCount: 0
    property bool _lastPowered: false

    Timer {
        interval: 1800
        running: root.enabled
        onTriggered: {
            root._lastCount = root.connectedCount;
            root._lastPowered = root.powered;
            root._settled = true;
        }
    }

    onConnectedCountChanged: {
        if (!_settled || connectedCount === _lastCount)
            return;
        const gained = connectedCount > _lastCount;
        _lastCount = connectedCount;
        changed(gained, root.deviceName);
    }

    onPoweredChanged: {
        if (!_settled || powered === _lastPowered)
            return;
        _lastPowered = powered;
        changed(powered, root.label);
    }
}
