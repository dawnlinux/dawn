import QtQuick
import Quickshell
import qs
import qs.theme
import qs.services

/*
 * The one place where "something happened" becomes "the island should show
 * this". Instantiated once, globally — not per monitor.
 *
 * Every service is deliberately ignorant of the island: they announce facts
 * (volume changed, a notification arrived) and this decides what that is worth
 * and for how long. That keeps the priority policy in one readable file
 * instead of smeared across nine services, and it is why the whole thing can
 * be re-tuned from Config without touching any of them.
 *
 * The Connections blocks are also what instantiate the service singletons —
 * Quickshell creates them lazily, so a service nothing refers to never starts.
 */
Item {
    id: root

    // ── Volume ────────────────────────────────────────────────────────────

    Connections {
        target: Audio
        enabled: Config.enableVolume
        function onChanged(volume, muted) {
            IslandState.request("volume", Config.volumeDuration);
        }
    }

    // ── Brightness ────────────────────────────────────────────────────────

    Connections {
        target: Brightness
        enabled: Config.enableBrightness
        function onChanged(level) {
            IslandState.request("brightness", Config.brightnessDuration);
        }
    }

    // ── Workspaces ────────────────────────────────────────────────────────

    Connections {
        target: Hypr
        enabled: Config.enableWorkspace
        function onWorkspaceSwitched(id, name) {
            IslandState.request("workspace", Config.workspaceDuration);
        }
    }

    // ── Clipboard ─────────────────────────────────────────────────────────

    Connections {
        target: Clipboard
        enabled: Config.enableClipboard
        function onCopied(preview, sensitive) {
            IslandState.request("clipboard", Config.clipboardDuration,
                                { preview: preview, sensitive: sensitive });
        }
    }

    // ── Notifications ─────────────────────────────────────────────────────

    Connections {
        target: Notifs
        enabled: Config.enableNotifications
        function onArrived(notification) {
            IslandState.request("notification", Config.notificationDuration, notification);
        }
    }

    // ── Media ─────────────────────────────────────────────────────────────
    //
    // A track change announces itself; a pause does not. Pausing is something
    // you just did on purpose, and being told about it is noise.

    Connections {
        target: Media
        enabled: Config.enableMedia
        function onTrackChanged() {
            IslandState.request("media", Config.mediaDuration);
        }
        function onPlayStateChanged(playing) {
            if (playing)
                IslandState.request("media", Config.mediaDuration);
        }
    }

    // ── Power ─────────────────────────────────────────────────────────────

    Connections {
        target: Power
        enabled: Config.enableBattery
        function onWarned(percent) {
            IslandState.request("battery", Config.batteryDuration);
        }
        function onPowerSourceChanged(onBattery) {
            IslandState.request("battery", Config.batteryDuration);
        }
    }

    // ── Network ───────────────────────────────────────────────────────────

    Connections {
        target: Net
        enabled: Config.enableNetwork
        function onConnectivityChanged(connected, kind) {
            IslandState.request("network", Config.networkDuration);
        }
    }

    // ── Bluetooth ─────────────────────────────────────────────────────────

    Connections {
        target: Bt
        enabled: Config.enableBluetooth
        function onChanged(active, name) {
            IslandState.request("bluetooth", Config.bluetoothDuration);
        }
    }

    // ── Keyboard panels ───────────────────────────────────────────────────
    //
    // The launcher, the status panel and the wallpaper carousel all take
    // exclusive keyboard focus, so only one may be up at a time. The priority
    // table would already hide the losers, but they would stay *open*
    // underneath and reappear when the winner closed — pressing the launcher
    // key and later escaping out of it should leave you at the desktop, not in
    // a panel you had forgotten about.

    readonly property var keyboardPanels: [Launcher, Nav, Wallpaper]

    function _closeOthers(winner) {
        for (const panel of keyboardPanels)
            if (panel !== winner && panel.open)
                panel.hide();
    }

    Connections {
        target: Launcher
        function onOpenChanged() { if (Launcher.open) root._closeOthers(Launcher); }
    }

    Connections {
        target: Nav
        function onOpenChanged() { if (Nav.open) root._closeOthers(Nav); }
    }

    Connections {
        target: Wallpaper
        function onOpenChanged() { if (Wallpaper.open) root._closeOthers(Wallpaper); }
    }

    // ── Expensive things, switched on only while visible ───────────────────
    //
    // Both of these are continuous streams. Gating them on what the island is
    // currently showing is the difference between an idle shell that wakes
    // once a minute and one that never sleeps.

    readonly property bool showingMedia:
        IslandState.current === "media" || IslandState.current === "expanded"

    Binding {
        target: Audio
        property: "peakEnabled"
        value: Config.showAudioWaveform && Media.isPlaying && root.showingMedia
    }

    Binding {
        target: Media
        property: "trackPosition"
        value: Config.showMediaProgress && root.showingMedia
    }

    // ── Hyprland integration ──────────────────────────────────────────────
    //
    // Blur behind the island is a compositor rule, not something the shell can
    // ask for at runtime: `keyword` is not a dispatcher, and on Hyprland 0.56
    // the dispatch IPC only accepts Lua dispatchers anyway. It belongs in
    // hyprland.conf, and is only worth adding when the island is translucent:
    //
    //   layerrule = blur, dawn-island
    //   layerrule = ignorezero, dawn-island
    //
    // See README.md; Config.requestHyprlandBlur only controls this reminder.
    Component.onCompleted: {
        if (Config.requestHyprlandBlur && Theme.backgroundOpacity < 1.0)
            console.log("[dawn-island] translucent island: add "
                        + "`layerrule = blur, " + Config.layerNamespace
                        + "` to hyprland.conf for the frosted-glass look.");
    }
}
