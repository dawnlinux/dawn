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

    /// ── Shape morph ──
    /// The island's width/height are driven by a real spring rather than a
    /// duration, so growing and shrinking are both physically correct and the
    /// motion stays continuous if a new state arrives mid-animation.
    /// These are QtQuick SpringAnimation units, tune them directly:
    ///   springStiffness — higher is snappier          (useful range 2 .. 12)
    ///   springDamping   — higher is less bouncy       (0 .. 1)
    ///   springMass      — higher is heavier/slower    (0.5 .. 3)
    property real springStiffness: 5.0
    property real springDamping: 0.34
    property real springMass: 1.0
    /// Stop the spring once it is within this many px of target.
    property real springEpsilon: 0.25

    /// Set false to morph with a plain eased curve instead of a spring.
    property bool useRealSpring: true
    /// Durations used when useRealSpring is false.
    property int expandDuration: 520
    property int collapseDuration: 420

    /// Content cross-fades, opacity, scale, progress fills.
    property int contentDuration: 220
    property int fadeDuration: 160

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

    /// Delay before a hover expands the island, and before it collapses again.
    property int hoverOpenDelay: 180
    property int hoverCloseDelay: 260

    // ─────────────────────────────────────────────────────────────────────
    //  State priority — higher wins. Tweak freely.
    // ─────────────────────────────────────────────────────────────────────

    readonly property var priority: ({
        "idle":         0,
        "media":        10,
        "network":      20,
        "battery":      25,
        "workspace":    30,
        "clipboard":    40,
        "brightness":   50,
        "volume":       55,
        "notification": 70,
        "expanded":     100
    })

    // ─────────────────────────────────────────────────────────────────────
    //  Feature switches
    // ─────────────────────────────────────────────────────────────────────

    property bool enableMedia: true
    property bool enableVolume: true
    property bool enableBrightness: true
    property bool enableWorkspace: true
    property bool enableClipboard: true
    property bool enableBattery: true
    property bool enableNetwork: true

    /// Quickshell must own org.freedesktop.Notifications to receive these.
    /// If another daemon (swaync, dunst, mako) is running it will win the bus
    /// name and this silently does nothing — stop that daemon first.
    property bool enableNotifications: true

    /// Show these in the expanded panel.
    property bool showClock: true
    property bool showCalendar: true
    property bool showBattery: true
    property bool showNetwork: true

    // ─────────────────────────────────────────────────────────────────────
    //  Interaction
    // ─────────────────────────────────────────────────────────────────────

    property bool expandOnHover: true
    property bool expandOnClick: true

    /// Scrolling over the notch adjusts volume.
    property bool scrollToChangeVolume: true

    /// Command run on right-click of the island (empty == nothing).
    property string rightClickCommand: ""

    /// Command run when the workspace indicator is clicked.
    property string workspaceClickCommand: ""

    /// Fired when the clipboard entry is clicked — opens the cliphist picker.
    property string clipboardPickerCommand:
        "sh -c 'cliphist list | rofi -dmenu -p Clipboard | cliphist decode | wl-copy'"

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
    //  Accent / wallpaper integration
    // ─────────────────────────────────────────────────────────────────────

    /// Derive the accent colour from the current wallpaper. Purely optional —
    /// everything works without it.
    property bool deriveAccentFromWallpaper: false

    /// Where to look for the wallpaper. Empty == try common awww/swww paths.
    property string wallpaperPath: ""

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
