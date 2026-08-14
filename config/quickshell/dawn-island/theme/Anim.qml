pragma Singleton

import QtQuick
import Quickshell
import qs

/*
 * Motion vocabulary.
 *
 * The island expands with a little overshoot and collapses without any — that
 * asymmetry is what separates "physical" from "robotic". Nothing here starts a
 * timer or runs continuously; these are just parameters that Behaviors read.
 */
Singleton {
    id: root

    // ── Durations ─────────────────────────────────────────────────────────
    readonly property int expand: Config.animationsEnabled ? Config.expandDuration : 0
    readonly property int collapse: Config.animationsEnabled ? Config.collapseDuration : 0
    readonly property int content: Config.animationsEnabled ? Config.contentDuration : 0
    readonly property int fade: Config.animationsEnabled ? Config.fadeDuration : 0
    readonly property int quick: Config.animationsEnabled ? Config.quickDuration : 0
    /// The accent crossfade when the wallpaper changes. Long by the standards
    /// of everything else here, because it is ambient rather than a response.
    readonly property int accent: Config.animationsEnabled ? Config.accentDuration : 0

    // ── Easing ────────────────────────────────────────────────────────────
    /// Used for the shape morph only when Config.useRealSpring is false.
    readonly property int expandEasing: Easing.OutBack
    readonly property real expandOvershoot: 0.9
    readonly property int collapseEasing: Easing.OutQuint

    /// Content swaps, opacity, scale.
    readonly property int contentEasing: Easing.OutCubic
    /// Progress bars, volume fills — linear-ish so they track input honestly.
    readonly property int trackEasing: Easing.OutQuad

    // ── Content transition geometry ───────────────────────────────────────
    /// New content rises into place from this offset and fades in.
    readonly property int enterOffset: 7
    /// Outgoing content sinks by this much as it fades.
    readonly property int exitOffset: -5
    /// Content starts marginally small so it "inflates" into the island.
    readonly property real enterScale: 0.94

    // ── Spring (drives the island's width/height morph) ───────────────────
    readonly property bool useSpring: Config.useRealSpring && Config.animationsEnabled
    readonly property real springStiffness: Config.springStiffness
    readonly property real springDamping: Config.springDamping
    readonly property real springMass: Config.springMass
    readonly property real springEpsilon: Config.springEpsilon
}
