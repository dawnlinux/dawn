pragma Singleton

import QtQuick
import Quickshell

/*
 * Every colour and elevation in the shell. Change it here, it changes
 * everywhere. Tuned to match the monochrome "dawn" palette already used by
 * the rest of this desktop (waybar-colors.css).
 */
Singleton {
    id: root

    // ── Surfaces ──────────────────────────────────────────────────────────
    /// The notch itself. The reference is pure black and it matters: a true
    /// black reads as absence-of-screen rather than as a widget.
    readonly property color background: "#000000"

    /// Opacity of the notch body. 1.0 keeps the "cut out of the display"
    /// illusion. Drop to ~0.82 and enable Config.requestHyprlandBlur for a
    /// frosted-glass island instead.
    property real backgroundOpacity: 1.0

    /// Raised chips inside the island (today pill, progress troughs, buttons).
    readonly property color surface: "#161616"
    readonly property color surfaceHigh: "#202020"
    readonly property color surfaceHighest: "#2b2b2b"

    /// Hairline that keeps the island from dissolving into a light wallpaper.
    /// Kept extremely faint — the reference has no visible edge at all.
    property bool showBorder: true
    readonly property color border: Qt.rgba(1, 1, 1, 0.06)

    /// Specular catch along the bottom curve. Off by default: the reference
    /// notch is flat pure black, and a visible sheen is exactly what makes a
    /// shell look like a widget rather than part of the display.
    property bool showHighlight: false
    readonly property color highlight: Qt.rgba(1, 1, 1, 0.10)

    /// Costs one render layer for the island surface, which is only rebuilt
    /// while the shape is actually morphing. Turn off on a weak GPU.
    property bool shadowEnabled: true
    readonly property color shadow: "#000000"
    readonly property real shadowOpacity: 0.55
    readonly property int shadowRadius: 28
    readonly property int shadowOffset: 6

    // ── Text ──────────────────────────────────────────────────────────────
    readonly property color text: "#f2f2f2"
    readonly property color textSecondary: "#b8b8b8"
    readonly property color textTertiary: "#8f8f8f"
    readonly property color textQuaternary: "#5a5a5a"

    // ── Accent ────────────────────────────────────────────────────────────
    /// Base accent. Monochrome by default, matching the rest of dawn.
    /// AccentService overrides `accent` when wallpaper derivation is enabled.
    readonly property color accentBase: "#f2f2f2"
    property color accent: accentBase

    readonly property color positive: "#7ec699"
    readonly property color warning: "#e8c07d"
    readonly property color danger: "#d9534f"
    /// Weekend column in the calendar strip.
    readonly property color weekend: "#e07a76"

    // ── Metrics ───────────────────────────────────────────────────────────
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacing: 12
    readonly property int spacingLg: 16
    readonly property int spacingXl: 22

    /// Inner padding between the island edge and its content.
    readonly property int padH: 15
    readonly property int padV: 10

    readonly property int radiusSm: 6
    readonly property int radius: 10
    readonly property int radiusLg: 14

    /// Album art / app icon. Also the height of the media pane — the text
    /// column is sized to match the artwork, not the other way round.
    readonly property int artSize: 64
    readonly property int artRadius: 12
    readonly property int iconSize: 34
    readonly property int iconRadius: 9

    /// Thickness of progress bars and rings.
    readonly property int trackThickness: 4
    readonly property int ringThickness: 3
}
