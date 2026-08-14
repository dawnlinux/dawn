pragma Singleton

import QtQuick
import Quickshell

/*
 * Type scale. Inter is used for everything readable; the Nerd Font supplies
 * glyphs. Sizes are deliberately small and tightly spaced — the island is a
 * dense object and large text makes it look like a toy.
 */
Singleton {
    id: root

    /// Falls back gracefully if inter-font is not installed.
    readonly property string family: "Inter"
    readonly property string familyFallback: "sans-serif"
    /// Nerd Font — supplies the Material Design icon glyphs in Glyphs.qml.
    readonly property string iconFamily: "JetBrainsMono Nerd Font"
    readonly property string monoFamily: "JetBrainsMono Nerd Font"

    // ── Sizes ─────────────────────────────────────────────────────────────
    readonly property int display: 30   // big clock in the expanded panel
    readonly property int clock: 21     // clock beside the media pane
    readonly property int title: 13     // track title, notification summary
    readonly property int body: 12      // notification body
    readonly property int label: 11     // artist, album, secondary rows
    readonly property int caption: 10   // calendar dates, percentages
    readonly property int micro: 9      // uppercase eyebrow text
    readonly property int icon: 15      // inline glyphs
    readonly property int iconLg: 19    // transport controls

    // ── Weights ───────────────────────────────────────────────────────────
    readonly property int regular: Font.Normal
    readonly property int medium: Font.Medium
    readonly property int semibold: Font.DemiBold
    readonly property int bold: Font.Bold

    // ── Tracking ──────────────────────────────────────────────────────────
    /// Uppercase eyebrow rows ("LAKEY INSPIRED", "COPIED") need positive
    /// tracking or they read as a smudge.
    readonly property real trackingWide: 0.9
    readonly property real trackingTight: -0.2

    /// Tabular figures — stops the clock and percentages jittering as digits
    /// change width. Qt 6.7+ only; harmless on older builds.
    readonly property var tabular: ({ "tnum": 1 })
}
