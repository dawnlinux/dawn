pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

/*
 * Default sink volume, mute and peak level, straight from PipeWire.
 *
 * No shelling out to wpctl: Quickshell talks to PipeWire natively, which means
 * changes made anywhere (media keys, pavucontrol, another app) arrive as
 * property updates rather than needing a poll.
 *
 * PwObjectTracker is not optional — without binding the node here, its `audio`
 * sub-object stays unpopulated and volume reads as 0 forever.
 */
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    readonly property bool ready: sink !== null && sink.ready && sink.audio !== null

    /// 0..1 (can exceed 1 if the sink is over-amplified).
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property int percent: Math.round(volume * 100)

    readonly property string deviceName:
        sink ? (sink.description || sink.nickname || sink.name || "") : ""

    readonly property bool micMuted:
        source !== null && source.ready && source.audio !== null ? source.audio.muted : false

    // ── Control ───────────────────────────────────────────────────────────

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.volume = Math.max(0, Math.min(1.5, v));
    }

    function step(delta) {
        setVolume(volume + delta);
    }

    function setMuted(m) {
        if (!ready)
            return;
        sink.audio.muted = m;
    }

    function toggleMute() {
        if (!ready)
            return;
        sink.audio.muted = !sink.audio.muted;
    }

    // ── Peak metering (drives the waveform) ───────────────────────────────

    /// Turned on only while something is actually displaying it. A peak
    /// monitor is a continuous stream of updates and must not run at idle.
    property bool peakEnabled: false

    PwNodePeakMonitor {
        id: peakMonitor
        node: root.peakEnabled ? root.sink : null
        enabled: root.peakEnabled && Config.showAudioWaveform
    }

    readonly property real peak: peakEnabled ? peakMonitor.peak : 0

    // ── Change detection ──────────────────────────────────────────────────
    //
    // Only announce *user-visible* changes, and never during startup: without
    // the settled guard the island would pop open the moment the shell loads,
    // just because PipeWire finished populating the node.

    property bool _settled: false
    property real _lastVolume: 0
    property bool _lastMuted: false

    Timer {
        id: settleTimer
        interval: 700
        running: root.ready
        onTriggered: {
            root._lastVolume = root.volume;
            root._lastMuted = root.muted;
            root._settled = true;
        }
    }

    signal changed(real volume, bool muted)

    onVolumeChanged: root._announce()
    onMutedChanged: root._announce()

    function _announce() {
        if (!_settled || !ready)
            return;
        // PipeWire emits tiny float jitter; ignore anything sub-percent.
        if (Math.abs(volume - _lastVolume) < 0.005 && muted === _lastMuted)
            return;
        _lastVolume = volume;
        _lastMuted = muted;
        changed(volume, muted);
    }
}
