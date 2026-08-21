pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * The palette. Every colour in the shell, and nothing else.
 *
 * The values are READ AT RUNTIME from ~/.config/dawn/generated/colors.json,
 * which `dawn-theme` renders through matugen. This file itself is static and
 * ships unchanged.
 *
 * ── Why JSON rather than a generated QML file ─────────────────────────────
 *
 * Because there is nowhere writable to put a generated one. In a packaged
 * install this directory is /usr/share/dawn/config/quickshell/dawn-island/
 * theme/ — root-owned and read-only — and ~/.config/quickshell/dawn-island is
 * a symlink straight into it. Quickshell resolves `qs.theme` to this
 * directory, so a generated QML file would have to live here, and it cannot.
 *
 * Reading data instead of generating code also means the shell repaints the
 * moment the file changes, with no restart: FileView watches it.
 *
 * ── The defaults below are load-bearing ───────────────────────────────────
 *
 * They are the palette a fresh install runs on, before dawn-theme has been
 * invoked for the first time and while colors.json does not exist. They are
 * exactly what `scheme-tonal-spot` on torii-ember.png produces — the shipped
 * default — so first boot and first theme run look identical.
 *
 * Regenerate them with:
 *   matugen -j hex --dry-run --prefer saturation -t scheme-tonal-spot \
 *     image assets/wallpapers/torii-ember.png
 *
 * Separate from Theme.qml because Theme.qml holds sizes, radii and spacing
 * that are hand-tuned: colours change with the wallpaper, 8px of padding does
 * not.
 */
Singleton {
    id: root

    /// Where dawn-theme writes the palette.
    readonly property string palettePath: Quickshell.env("HOME") + "/.config/dawn/generated/colors.json"

    FileView {
        path: root.palettePath

        // Repaint on change. dawn-theme rewrites this file on every theme
        // switch, and the shell should follow without being restarted.
        watchChanges: true
        onFileChanged: reload()

        // A missing file is the NORMAL state of a fresh install, not an
        // error: the JsonAdapter defaults below stand in until dawn-theme
        // runs for the first time. Without this, Quickshell logs a warning
        // on every start until someone picks a theme.
        printErrors: false

        JsonAdapter {
            id: palette

            // ── Surfaces ──────────────────────────────────────────────────
            /// The notch itself. A very dark warm brown rather than pure
            /// black: Material You tints even its darkest surface with the
            /// wallpaper's hue, and torii-ember is a sunset.
            property string background: "#19120d"
            property string surface: "#261e18"
            property string surfaceHigh: "#312822"
            property string surfaceHighest: "#3c332d"

            // ── Overlay bases ─────────────────────────────────────────────
            /// Tinted by the palette but applied at low alpha by Theme.qml.
            /// The alpha belongs to the design, not the palette — a solid
            /// outline colour would replace a hairline with a visible border.
            property string borderBase: "#52443b"
            property string highlightBase: "#9f8d82"

            property string shadow: "#000000"

            // ── Text ──────────────────────────────────────────────────────
            property string text: "#f0dfd6"
            property string textSecondary: "#d6c3b7"
            property string textTertiary: "#9f8d82"
            property string textQuaternary: "#52443b"

            // ── Accent ────────────────────────────────────────────────────
            property string accentBase: "#ffb781"
            /// A filled accent surface and legible text on top of it.
            property string accentContainer: "#6d3a09"
            property string onAccent: "#4e2600"

            // ── Semantic ──────────────────────────────────────────────────
            /// NOT derived from the wallpaper. Material You defines an error
            /// role but has no success or warning role, and a low-battery
            /// warning that changes hue has stopped communicating urgency.
            property string positive: "#7ec699"
            property string warning: "#e8c07d"

            property string danger: "#ffb4ab"
            property string weekend: "#c7ca95"
        }
    }

    // ── Typed surface ─────────────────────────────────────────────────────
    //
    // JsonAdapter holds strings; the shell wants colours. Converting here
    // once means no call site has to care that the palette arrives as text.

    readonly property color background: palette.background
    readonly property color surface: palette.surface
    readonly property color surfaceHigh: palette.surfaceHigh
    readonly property color surfaceHighest: palette.surfaceHighest

    readonly property color borderBase: palette.borderBase
    readonly property color highlightBase: palette.highlightBase

    readonly property color shadow: palette.shadow

    readonly property color text: palette.text
    readonly property color textSecondary: palette.textSecondary
    readonly property color textTertiary: palette.textTertiary
    readonly property color textQuaternary: palette.textQuaternary

    readonly property color accentBase: palette.accentBase
    readonly property color accentContainer: palette.accentContainer
    readonly property color onAccent: palette.onAccent

    readonly property color positive: palette.positive
    readonly property color warning: palette.warning
    readonly property color danger: palette.danger
    readonly property color weekend: palette.weekend
}
