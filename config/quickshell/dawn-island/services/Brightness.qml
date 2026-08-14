pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

/*
 * Backlight level, driven by udev events rather than polling.
 *
 * Two things were established empirically on this machine before settling on
 * this design:
 *   · FileView's inotify watch does NOT fire for /sys/class/backlight/*
 *     (sysfs attributes don't generate inotify events), so watching the file
 *     silently never updates.
 *   · `udevadm monitor --udev --subsystem-match=backlight` DOES emit a
 *     "change" line on every brightness write.
 *
 * So: one long-lived udevadm process supplies the events (idle cost ~0), and
 * each event triggers a single brightnessctl read. Nothing is polled.
 */
Singleton {
    id: root

    property string device: Config.backlightDevice
    readonly property bool available: device !== "" && max > 0

    property int raw: 0
    property int max: 0

    /// 0..1
    readonly property real level: max > 0 ? raw / max : 0
    readonly property int percent: Math.round(level * 100)

    signal changed(real level)

    property bool _settled: false

    // ── Device discovery ──────────────────────────────────────────────────
    // Picks the first backlight device unless one is pinned in Config.
    // Prefers a real panel backlight over acpi_video* when both exist.

    Process {
        id: detect
        running: Config.enableBrightness && Config.backlightDevice === ""
        command: ["sh", "-c", "ls -1 /sys/class/backlight/ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.trim().split("\n").filter(n => n.length > 0);
                if (names.length === 0)
                    return;
                const preferred = names.find(n => !n.startsWith("acpi_video"));
                root.device = preferred !== undefined ? preferred : names[0];
            }
        }
    }

    onDeviceChanged: refresh()

    // ── Reading ───────────────────────────────────────────────────────────
    //
    // The command is assigned at call time rather than bound to `device`.
    // Bound, the very first read raced the device detection and ran as
    // `brightnessctl -d "" info`, which fails and produces no output — so the
    // *next* read, caused by a real keypress, became the baseline and that
    // first brightness change was silently swallowed. Assigning here means a
    // read can only ever run against a device we already know.

    Process {
        id: readNow
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent%,max
                const parts = text.trim().split(",");
                if (parts.length < 5)
                    return;
                const cur = parseInt(parts[2]);
                const mx = parseInt(parts[4]);
                if (isNaN(cur) || isNaN(mx) || mx <= 0)
                    return;

                const baseline = !root._settled;
                const moved = cur !== root.raw || mx !== root.max;

                root.max = mx;
                root.raw = cur;

                if (baseline)
                    root._settled = true;       // the level at startup is not news
                else if (moved)
                    root.changed(root.level);   // a re-read that found nothing new isn't either
            }
        }
    }

    function refresh() {
        if (root.device === "" || readNow.running)
            return;
        readNow.command = ["brightnessctl", "-m", "-d", root.device, "info"];
        readNow.running = true;
    }

    // ── Control ───────────────────────────────────────────────────────────

    function setPercent(p) {
        if (!available)
            return;
        const clamped = Math.max(1, Math.min(100, Math.round(p)));
        setter.command = ["brightnessctl", "-d", root.device, "-n", "set", clamped + "%"];
        setter.running = true;
    }

    function step(deltaPercent) {
        setPercent(percent + deltaPercent);
    }

    Process { id: setter }

    // ── Event source ──────────────────────────────────────────────────────

    Process {
        id: udevMonitor
        running: Config.enableBrightness
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                if (line.indexOf("change") !== -1)
                    root.refresh();
            }
        }
    }
}
