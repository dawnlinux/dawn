pragma Singleton

import QtQuick
import Quickshell

/*
 * dawn-island — central configuration.
 *
 * Everything tunable lives here. Nothing else in the project should hardcode a
 * duration, a size or a feature switch. Colours live in theme/Theme.qml.
 */
Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────────────
    //  Placement
    // ─────────────────────────────────────────────────────────────────────

    /// Monitors to show the island on.
    ///   []                  → every monitor
    ///   ["eDP-1"]           → only that monitor
    ///   ["eDP-1","HDMI-A-3"]→ those monitors
    property var monitors: []

    /// Show only on the monitor that currently has focus. Overrides `monitors`
    /// filtering when true (the island follows you between screens).
    property bool followFocusedMonitor: false

    /// Distance from the top edge of the screen.
    ///   0  → flush with the bezel, square top corners: a real notch.
    ///   >0 → a floating pill with all four corners rounded.
    /// The reference uses the floating variant, so that is the default.
    property int topMargin: 8

    /// Space reserved so tiled windows never sit under the notch.
    /// Set to 0 if you would rather windows flow underneath it.
    property int exclusiveZone: islandHeight + topMargin

    // ─────────────────────────────────────────────────────────────────────
    //  Geometry
    // ─────────────────────────────────────────────────────────────────────

    /// The resting notch — deliberately small and anonymous. Just the time.
    property int islandWidth: 124
    property int islandHeight: 28

    /// Slim contextual pills (volume, brightness, workspace, clipboard).
    property int pillWidth: 258
    property int pillHeight: 38

    /// Notification banner.
    property int notificationWidth: 404
    property int notificationHeight: 80

    /// Media view — art + text + transport, no calendar.
    property int mediaWidth: 380
    property int mediaHeight: 94

    /// Fully expanded panel (hover / click): media pane + clock & calendar pane.
    property int expandedWidth: 470
    property int expandedHeight: 94

    /// Wallpaper carousel. Wider than the other panels because it is the only
    /// one whose content is the point rather than a label — the tiles need
    /// enough room to be recognisable at a glance.
    property int wallpaperWidth: 640
    property int wallpaperHeaderHeight: 32
    /// The centred tile. Neighbours scale down from this along the path.
    property int wallpaperTileWidth: 176
    property int wallpaperTileHeight: 99      // 16:9
    /// How many tiles are on the path at once. Odd numbers centre cleanly.
    property int wallpaperVisibleTiles: 5

    /// Session / power carousel. Tiles are square-ish cards rather than the
    /// wallpaper's 16:9 crops — an icon and a word, not a picture.
    property int powerWidth: 520
    property int powerHeaderHeight: 32
    property int powerTileWidth: 122
    property int powerTileHeight: 96
    property int powerVisibleTiles: 5

    /// Notification centre. Rows are taller than the status panel's because
    /// each carries three lines — app, summary, body — not one.
    property int notifCenterWidth: 430
    property int notifCenterHeaderHeight: 32
    property int notifCenterRowHeight: 64
    /// The list scrolls past this; the island does not keep growing.
    property int notifCenterMaxRows: 5

    /// Keyboard-driven status panel (wifi, bluetooth, battery, volume,
    /// brightness). Sized like the launcher so the two read as one family.
    property int statusWidth: 360
    property int statusRowHeight: 42
    property int statusHeaderHeight: 30

    /// App launcher.
    property int launcherWidth: 460
    property int launcherSearchHeight: 46
    property int launcherRowHeight: 44
    /// How many results are on screen at once. The island grows to fit fewer,
    /// so a narrow query makes it smaller rather than leaving empty rows.
    property int launcherMaxRows: 6

    /// Keybind cheatsheet. Wider than the launcher because each row carries a
    /// key chord and a sentence, and taller because it is read rather than
    /// filtered — you scroll it instead of typing at it.
    property int keybindsWidth: 620
    property int keybindsHeaderHeight: 34
    property int keybindsRowHeight: 32
    property int keybindsMaxRows: 12
    property int keybindsFooterHeight: 26
    /// Ctrl+D / Ctrl+U step by this many rows.
    property int keybindsPageSize: 6
    /// Fixed column for the key chord so every description starts aligned.
    property int keybindsChordWidth: 210

    /// Corner radii. A notch is square where it meets the bezel and generously
    /// rounded where it meets the desktop.
    property int cornerRadius: 22          // bottom corners
    property int topCornerRadius: 0        // top corners (0 == flush with edge)

    /// Radius applied when the island is not touching the top edge
    /// (topMargin > 0), so it reads as a floating pill instead.
    property int floatingRadius: 15

    /// Extra room around the island inside its layer-shell window, so the
    /// drop shadow and the spring's overshoot are never clipped.
    property int shadowPadding: 46

    // ─────────────────────────────────────────────────────────────────────
    //  Motion
    // ─────────────────────────────────────────────────────────────────────

    /// Master switch — set false for a completely static island.
    property bool animationsEnabled: true

    /// Crossfade from the old accent to the new one when dawn-theme writes a
    /// new palette. Follows animationsEnabled like every other duration.
    property int accentDuration: 800

    /// ── Shape morph ──
    /// The island's width/height are driven by a real spring rather than a
    /// duration, so growing and shrinking are both physically correct and the
    /// motion stays continuous if a new state arrives mid-animation.
    /// These are QtQuick SpringAnimation units, tune them directly:
    ///   springStiffness — higher is snappier          (useful range 2 .. 12)
    ///   springDamping   — higher is less bouncy       (0 .. 1)
    ///   springMass      — higher is heavier/slower    (0.5 .. 3)
    /// Tuned snappy: a stiff, light spring that arrives fast and settles in
    /// roughly a third of a second, with just enough bounce left to read as
    /// physical rather than as a jump cut. Drop stiffness to ~5 and raise mass
    /// to 1.0 for the softer, more languid original feel.
    property real springStiffness: 11.0
    property real springDamping: 0.46
    property real springMass: 0.7
    /// Stop the spring once it is within this many px of target.
    property real springEpsilon: 0.3

    /// Set false to morph with a plain eased curve instead of a spring.
    property bool useRealSpring: true
    /// Durations used when useRealSpring is false.
    property int expandDuration: 340
    property int collapseDuration: 280

    /// Content cross-fades, opacity, scale, progress fills.
    property int contentDuration: 150
    property int fadeDuration: 100

    /// Small feedback animations — button presses, hover washes.
    property int quickDuration: 90

    // ─────────────────────────────────────────────────────────────────────
    //  Behaviour — how long each contextual state stays up (ms)
    // ─────────────────────────────────────────────────────────────────────

    property int volumeDuration: 1600
    property int brightnessDuration: 1600
    property int workspaceDuration: 1100
    property int clipboardDuration: 2200
    property int notificationDuration: 4500
    property int mediaDuration: 4000
    property int batteryDuration: 4000
    property int networkDuration: 2600
    property int bluetoothDuration: 2600

    /// Delay before a hover expands the island, and before it collapses again.
    /// Opening is near-instant so the island feels responsive; closing keeps a
    /// little slack so crossing a gap on the way to a button doesn't collapse
    /// it under the pointer.
    property int hoverOpenDelay: 80
    property int hoverCloseDelay: 200

    // ─────────────────────────────────────────────────────────────────────
    //  State priority — higher wins. Tweak freely.
    // ─────────────────────────────────────────────────────────────────────

    readonly property var priority: ({
        "idle":         0,
        "media":        10,
        "network":      20,
        "bluetooth":    22,
        "battery":      25,
        "workspace":    30,
        "clipboard":    40,
        "brightness":   50,
        "volume":       55,
        "notification": 70,
        "expanded":     100,
        /// The launcher, the status panel and the wallpaper carousel are the
        /// states the user opened deliberately, so nothing may interrupt them.
        "status":       190,
        "notifcenter":  192,
        "wallpaper":    195,
        /// Above the rest: if you asked to shut the machine down, nothing
        /// arriving afterwards is more important than that question.
        "power":        198,
        /// Below the launcher and the session menu, above the carousel.
        ///
        /// NOT level with the launcher: _recompute picks the first state with
        /// a strictly greater priority, so a tie is resolved by whichever key
        /// happens to be iterated first — which is to say, arbitrarily.
        "keybinds":     196,
        "launcher":     200
    })

    // ─────────────────────────────────────────────────────────────────────
    //  Feature switches
    // ─────────────────────────────────────────────────────────────────────

    property bool enableLauncher: true
    property bool enableMedia: true
    property bool enableVolume: true
    property bool enableBrightness: true
    property bool enableWorkspace: true
    property bool enableClipboard: true
    property bool enableBattery: true
    property bool enableNetwork: true
    property bool enableBluetooth: true

    /// The keyboard-driven status panel. Off means the shortcut does nothing;
    /// the rows still show in the hover panel.
    property bool enableStatusPanel: true

    /// The wallpaper carousel.
    property bool enableWallpaper: true

    /// The notification centre. Off leaves the transient banners working and
    /// only removes the history panel.
    property bool enableNotifCenter: true

    /// The session / power carousel.
    property bool enablePower: true

    /// Quickshell must own org.freedesktop.Notifications to receive these.
    /// If another daemon (swaync, dunst, mako) is running it will win the bus
    /// name and this silently does nothing — stop that daemon first.
    property bool enableNotifications: true

    /// Show these in the expanded panel.
    /// The keybind cheatsheet, read live from `hyprctl binds`.
    property bool enableKeybinds: true

    property bool showClock: true
    property bool showCalendar: true
    property bool showBattery: true
    property bool showNetwork: true
    property bool showBluetooth: true

    // ─────────────────────────────────────────────────────────────────────
    //  Interaction
    // ─────────────────────────────────────────────────────────────────────

    property bool expandOnHover: true
    property bool expandOnClick: true

    /// Show the Arch logo beside the clock on the resting notch. Clicking it
    /// opens the launcher.
    property bool showDistroLogo: true

    /// Global shortcut names. Bind them in hyprland.conf with:
    ///   hl.bind("SUPER + SPACE",  hl.dsp.global("quickshell:launcher"))
    ///   hl.bind("SUPER + I",      hl.dsp.global("quickshell:status"))
    ///   hl.bind("SUPER + PERIOD", hl.dsp.global("quickshell:island"))
    readonly property string launcherShortcut: "launcher"
    readonly property string statusShortcut: "status"
    readonly property string islandShortcut: "island"
    readonly property string wallpaperShortcut: "wallpaper"
    readonly property string notificationsShortcut: "notifications"
    readonly property string powerShortcut: "power"

    /// The keybind cheatsheet. Bound in binds.lua to Ctrl+?.
    readonly property string keybindsShortcut: "keybinds"

    /// Step sizes for the status panel's Left/Right keys.
    property real volumeKeyStep: 0.05
    property int brightnessKeyStep: 5

    /// Scrolling over the notch adjusts volume.
    property bool scrollToChangeVolume: true

    /// Command run on right-click of the island (empty == nothing).
    property string rightClickCommand: ""

    /// Command run when the workspace indicator is clicked.
    property string workspaceClickCommand: ""

    /// Fired when the clipboard entry is clicked — opens the cliphist picker.
    property string clipboardPickerCommand:
        "sh -c 'cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy'"

    /// Enter on the status panel's wifi / bluetooth rows opens the real thing:
    /// picking a network or pairing a device needs a list, a password prompt
    /// and a scan, which is a terminal's job and not a notch's. The island
    /// keeps the parts that fit in one line — the radio switch and the state.
    ///
    /// Both float via their --class; add matching rules in windowrules.lua.
    property string wifiCommand: "kitty --class floating-nmtui -e nmtui"
    property string bluetoothCommand: "kitty --class floating-bluetui -e bluetui"

    // ─────────────────────────────────────────────────────────────────────
    //  Media
    // ─────────────────────────────────────────────────────────────────────

    /// Players to ignore entirely (substring match on the MPRIS bus name and
    /// identity). Browsers are deliberately *not* blocked by default — on a
    /// Linux desktop the browser is usually the media player, and filtering it
    /// out means the island shows nothing for most of what you actually play.
    /// Add "firefox" / "chromium" here if you only want native players.
    property var mediaBlacklist: ["kdeconnect"]

    /// Show a live PipeWire-driven waveform next to the album art.
    property bool showAudioWaveform: true
    property int waveformBars: 4

    /// Show the track progress bar under the media text.
    property bool showMediaProgress: true

    // ─────────────────────────────────────────────────────────────────────
    //  Notifications
    // ─────────────────────────────────────────────────────────────────────

    property int notificationTitleLength: 46
    property int notificationBodyLength: 110

    /// Apps whose notifications never expand the island.
    property var notificationBlacklist: []

    // ─────────────────────────────────────────────────────────────────────
    //  Clipboard
    // ─────────────────────────────────────────────────────────────────────

    property int clipboardPreviewLength: 52

    /// Start `wl-paste --watch cliphist store` if it isn't already running.
    /// Without a watcher, cliphist records no history and the picker is empty.
    property bool startClipboardDaemon: true

    /// Never preview clipboard content that looks sensitive. The island shows
    /// "Copied · hidden" instead. Patterns are case-insensitive regexes.
    property bool sanitizeClipboard: true
    property var clipboardSecretPatterns: [
        "password", "passwd", "secret", "token", "api[_-]?key",
        "bearer ", "private[_-]?key", "BEGIN [A-Z ]*PRIVATE KEY",
        "ghp_[A-Za-z0-9]{20,}", "sk-[A-Za-z0-9]{20,}", "xox[baprs]-"
    ]

    // ─────────────────────────────────────────────────────────────────────
    //  Brightness
    // ─────────────────────────────────────────────────────────────────────

    /// Backlight device under /sys/class/backlight. Empty == auto-detect.
    property string backlightDevice: ""

    // ─────────────────────────────────────────────────────────────────────
    //  Battery
    // ─────────────────────────────────────────────────────────────────────

    /// Announce when the battery drops past any of these percentages.
    property var batteryWarnLevels: [20, 10, 5]

    // ─────────────────────────────────────────────────────────────────────
    //  Session / power
    // ─────────────────────────────────────────────────────────────────────

    /// Log out goes through uwsm because SDDM starts this session with
    /// `uwsm start -e -D Hyprland`, which makes the compositor a systemd user
    /// unit. Killing Hyprland directly strands that unit; `uwsm stop` is the
    /// wind-down the session manager expects. On a session started some other
    /// way, `hyprctl dispatch "hl.dsp.exit()"` is the right value here.
    property string logoutCommand: "uwsm stop"
    property string sleepCommand: "systemctl suspend"
    property string restartCommand: "systemctl reboot"
    property string shutdownCommand: "systemctl poweroff"

    /// Only offered when one of these is actually installed — see Session.qml.
    property string lockCommand: "hyprlock"

    /// How long a destructive tile stays armed waiting for the second Enter.
    property int powerConfirmTimeout: 3000

    // ─────────────────────────────────────────────────────────────────────
    //  Wallpaper
    // ─────────────────────────────────────────────────────────────────────

    readonly property string home: Quickshell.env("HOME") || ""

    /// Where the carousel looks. Every image directly inside is offered; there
    /// is no recursion, because a wallpaper folder with subfolders in it is a
    /// photo library and this is not a file manager.
    property string wallpaperDir: home + "/Pictures/Wallpapers"

    property var wallpaperExtensions: ["png", "jpg", "jpeg", "webp", "gif", "bmp"]

    /// How the wallpaper is applied. `{}` is replaced with the shell-quoted
    /// path. The random transition is deliberate — awww picks a different
    /// wipe/grow/wave each time, so changing wallpaper never looks routine.
    property string wallpaperCommand:
        "awww img {} --transition-type random --transition-duration 1.2 --transition-fps 60"

    /// Where the island records the wallpaper it just applied, so the login
    /// screen can show the same one. dawn-greet runs as the unprivileged
    /// `greeter` user under greetd and cannot read your home directory or ask
    /// awww, so a plain file it *can* read is the only way across.
    /// Empty disables the write. See dawn-greet/README.md.
    property string wallpaperPointer: "/var/lib/dawn/wallpaper"

    // ─────────────────────────────────────────────────────────────────────
    //  Integration
    // ─────────────────────────────────────────────────────────────────────

    /// Ask Hyprland to blur behind the island. Only meaningful when
    /// Theme.backgroundOpacity < 1.
    property bool requestHyprlandBlur: true

    /// Layer-shell namespace, used by the Hyprland layerrule above.
    readonly property string layerNamespace: "dawn-island"

    /// Hyprland 0.56 replaced string dispatchers with a Lua API. Leave true on
    /// 0.56+; set false on older Hyprland, where dispatchers are still plain
    /// strings ("workspace 3"). See services/Hypr.qml.
    property bool hyprlandLuaDispatch: true

    /// Print state transitions to the log.
    property bool debug: false
}
