pragma Singleton

import QtQuick
import Quickshell

/*
 * The palette. Every colour in the shell, and nothing else.
 *
 * THIS FILE IS GENERATED once the colour engine is wired up — see
 * config/matugen/templates/quickshell-colors.qml. Edit that template, not
 * this file.
 *
 * It is separate from Theme.qml because Theme.qml also holds sizes, radii and
 * spacing that are hand-tuned and must not be machine-written. Colours change
 * with the wallpaper; 8px of padding does not.
 *
 * The values below are the built-in default: scheme-monochrome derived from
 * dawn-black.png, which is Dawn's original hand-tuned identity.
 */
Singleton {
    id: root

    // ── Surfaces ──────────────────────────────────────────────────────────
    /// The notch itself. The reference is pure black and it matters: a true
    /// black reads as absence-of-screen rather than as a widget.
    readonly property color background: "#000000"
    readonly property color surface: "#161616"
    readonly property color surfaceHigh: "#202020"
    readonly property color surfaceHighest: "#2b2b2b"

    // ── Overlay bases ─────────────────────────────────────────────────────
    /// Tinted by the palette but applied at low alpha by Theme.qml. Kept as
    /// solid colours here so the template has somewhere to write; the alpha
    /// belongs to the design, not to the palette. A solid outline colour used
    /// directly would replace a hairline with a visible border.
    readonly property color borderBase: "#ffffff"
    readonly property color highlightBase: "#ffffff"

    readonly property color shadow: "#000000"

    // ── Text ──────────────────────────────────────────────────────────────
    readonly property color text: "#f2f2f2"
    readonly property color textSecondary: "#b8b8b8"
    readonly property color textTertiary: "#8f8f8f"
    readonly property color textQuaternary: "#5a5a5a"

    // ── Accent ────────────────────────────────────────────────────────────
    readonly property color accentBase: "#f2f2f2"
    /// The container/on-container pair, for anything that needs a filled
    /// accent surface with legible text on top of it.
    readonly property color accentContainer: "#2b2b2b"
    readonly property color onAccent: "#000000"

    // ── Semantic ──────────────────────────────────────────────────────────
    /// NOT generated. Material You defines an error role but has no success or
    /// warning role, and a low-battery warning that changes hue with the
    /// wallpaper has stopped communicating urgency.
    readonly property color positive: "#7ec699"
    readonly property color warning: "#e8c07d"

    readonly property color danger: "#d9534f"
    readonly property color weekend: "#e07a76"
}
