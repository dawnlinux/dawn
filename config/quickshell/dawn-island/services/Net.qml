pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import qs

/*
 * Network state via Quickshell's NetworkManager binding — no nmcli polling.
 *
 * Ethernet outranks wifi when both are up, which matches how routing actually
 * behaves and avoids the island claiming you're on wifi while a cable is doing
 * the work.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.enableNetwork
    readonly property var devices: Networking.devices ? Networking.devices.values : []

    readonly property var wifiDevice: devices.find(d => d && d.type === DeviceType.Wifi) || null
    readonly property var wiredDevice: devices.find(d => d && d.type === DeviceType.Ethernet) || null

    readonly property bool wiredUp: wiredDevice !== null && wiredDevice.connected
    readonly property bool wifiUp: wifiDevice !== null && wifiDevice.connected
    readonly property bool wifiEnabled: Networking.wifiEnabled

    readonly property bool connected: wiredUp || wifiUp

    /// The network object for the active wifi connection, if any.
    readonly property var activeWifi: {
        if (!wifiDevice || !wifiDevice.networks)
            return null;
        const nets = wifiDevice.networks.values;
        return nets.find(n => n && n.connected) || null;
    }

    readonly property string ssid: activeWifi ? (activeWifi.name || "") : ""

    /// 0..1. NetworkManager reports 0..100; normalised, with a fraction guard.
    readonly property real strength: {
        if (!activeWifi)
            return 0;
        const s = activeWifi.signalStrength;
        return s > 1.0 ? Math.max(0, Math.min(1, s / 100)) : Math.max(0, Math.min(1, s));
    }

    /// "ethernet" | "wifi" | "offline"
    readonly property string kind: wiredUp ? "ethernet" : (wifiUp ? "wifi" : "offline")

    readonly property string label: {
        if (wiredUp) return "Ethernet";
        if (wifiUp) return ssid !== "" ? ssid : "Wi-Fi";
        if (!wifiEnabled) return "Wi-Fi off";
        return "Offline";
    }

    readonly property string address: {
        if (wiredUp && wiredDevice) return wiredDevice.address || "";
        if (wifiUp && wifiDevice) return wifiDevice.address || "";
        return "";
    }

    /// NetworkManager owns the radio state and reports it back through
    /// `wifiEnabled`, so nothing here tracks it optimistically.
    function setWifi(on) {
        Networking.wifiEnabled = on;
    }

    function toggleWifi() {
        setWifi(!Networking.wifiEnabled);
    }

    signal connectivityChanged(bool connected, string kind)

    property bool _settled: false
    property string _lastKind: ""

    Timer {
        interval: 1800
        running: root.enabled
        onTriggered: {
            root._lastKind = root.kind;
            root._settled = true;
        }
    }

    onKindChanged: {
        if (!_settled || kind === _lastKind)
            return;
        _lastKind = kind;
        connectivityChanged(connected, kind);
    }
}
