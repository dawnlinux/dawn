pragma Singleton

import QtQuick
import Quickshell

/*
 * dawn-greet — the login screen's palette and motion.
 *
 * Deliberately a copy of dawn-island's values rather than an import of them.
 * The greeter runs as a different user, in a different compositor, before the
 * island exists; a shared module would be a dependency across a boundary that
 * cannot be crossed. Two files agreeing on #161616 is the cheaper problem.
 */
Singleton {
    id: root

    // ── Colour ────────────────────────────────────────────────────────────

    readonly property color background: "#000000"
    readonly property color surface: "#161616"
    readonly property color surfaceHigh: "#202020"
    readonly property color surfaceHighest: "#2b2b2b"

    readonly property color border: Qt.rgba(1, 1, 1, 0.07)

    readonly property color text: "#f2f2f2"
    readonly property color textSecondary: "#b8b8b8"
    readonly property color textTertiary: "#8f8f8f"
    readonly property color textQuaternary: "#5a5a5a"

    readonly property color accent: "#f2f2f2"
    readonly property color positive: "#7ec699"
    readonly property color danger: "#d9534f"

    /// The aurora's three drifting fields. Desaturated and barely there — the
    /// island is monochrome and this has to read as the same product, not as a
    /// gaming rig. Anything above ~0.18 alpha starts to look like a wallpaper.
    readonly property color auroraA: "#3a4a7a"
    readonly property color auroraB: "#6a3a6e"
    readonly property color auroraC: "#24506b"

    // ── Type ──────────────────────────────────────────────────────────────

    readonly property string family: "Inter"
    readonly property string monoFamily: "JetBrainsMono Nerd Font"

    /// The clock is the largest thing on the screen by a wide margin, and thin
    /// rather than bold — at this size weight reads as shouting.
    readonly property int clock: 132
    readonly property int date: 21
    readonly property int name: 15
    readonly property int body: 14
    readonly property int label: 12
    readonly property int caption: 11
    readonly property int micro: 10

    readonly property int light: Font.Light
    readonly property int regular: Font.Normal
    readonly property int medium: Font.Medium
    readonly property int semibold: Font.DemiBold

    readonly property var tabular: ({ "tnum": 1 })

    // ── Metrics ───────────────────────────────────────────────────────────

    readonly property int radius: 10
    readonly property int radiusLg: 18
    readonly property int cardRadius: 26

    /// The resting pill the password field unfolds from — the island's notch.
    readonly property int pillWidth: 124
    readonly property int pillHeight: 28

    /// The password field, once unfolded.
    readonly property int fieldWidth: 232
    readonly property int fieldHeight: 34

    readonly property int avatarSize: 76

    // ── Motion ────────────────────────────────────────────────────────────
    //
    // The same spring as the island, so the greeter and the shell that follows
    // it move like one machine.

    readonly property real springStiffness: 11.0
    readonly property real springDamping: 0.46
    readonly property real springMass: 0.7
    readonly property real springEpsilon: 0.3

    readonly property int quick: 90
    readonly property int content: 150
    readonly property int slow: 420
}
