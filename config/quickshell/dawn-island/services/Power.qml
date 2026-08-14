pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

/*
 * Battery and AC state via UPower.
 *
 * Announcements are edge-triggered, not level-triggered: crossing 20% fires
 * once, and won't fire again while hovering at 20.4% / 19.6%. A level check
 * would re-announce on every UPower update at exactly the wrong moment.
 */
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available:
        Config.enableBattery && device !== null && device.ready && device.isLaptopBattery && device.isPresent

    /// UPower reports 0..100; normalised here to 0..1 for the UI, with a guard
    /// in case a future version switches to a fraction.
    readonly property real fraction: {
        if (!device) return 0;
        const p = device.percentage;
        return p > 1.0 ? Math.max(0, Math.min(1, p / 100)) : Math.max(0, Math.min(1, p));
    }
    readonly property int percent: Math.round(fraction * 100)

    readonly property bool onBattery: UPower.onBattery
    readonly property bool charging:
        device !== null && (device.state === UPowerDeviceState.Charging
                         || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: device !== null && device.state === UPowerDeviceState.FullyCharged

    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0

    readonly property bool low: available && !charging && percent <= Config.batteryWarnLevels[0]
    readonly property bool critical:
        available && !charging
        && percent <= Config.batteryWarnLevels[Config.batteryWarnLevels.length - 1]

    signal warned(int percent)
    signal powerSourceChanged(bool onBattery)

    function formatDuration(seconds) {
        if (!isFinite(seconds) || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    /// Human-readable summary for the expanded panel.
    readonly property string summary: {
        if (!available) return "";
        if (full) return "Fully charged";
        if (charging) {
            const t = formatDuration(timeToFull);
            return t ? t + " to full" : "Charging";
        }
        const t = formatDuration(timeToEmpty);
        return t ? t + " left" : "On battery";
    }

    // ── Edge-triggered warnings ───────────────────────────────────────────

    property bool _settled: false
    property int _lastWarned: 101
    property bool _lastOnBattery: false

    Timer {
        interval: 1500
        running: root.available
        onTriggered: {
            root._lastOnBattery = root.onBattery;
            root._lastWarned = root.percent;
            root._settled = true;
        }
    }

    onPercentChanged: {
        if (!_settled || !available)
            return;

        if (charging) {
            _lastWarned = 101;   // re-arm all thresholds once back on AC
            return;
        }

        for (const level of Config.batteryWarnLevels) {
            if (percent <= level && _lastWarned > level) {
                _lastWarned = percent;
                warned(percent);
                return;
            }
        }
        if (percent > _lastWarned)
            _lastWarned = percent;
    }

    onOnBatteryChanged: {
        if (!_settled)
            return;
        if (onBattery === _lastOnBattery)
            return;
        _lastOnBattery = onBattery;
        powerSourceChanged(onBattery);
    }
}
