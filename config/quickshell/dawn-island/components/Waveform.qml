import QtQuick
import qs
import qs.theme

/*
 * Audio level bars.
 *
 * Driven by the real PipeWire peak of the playing sink, not a canned loop —
 * but note it is a *level* meter, not a spectrum analyser: PipeWire gives us
 * amplitude per channel, not per frequency band. Each bar therefore takes the
 * same peak with a different weight and a different decay time, which is what
 * produces the staggered, alive look without pretending to show frequencies.
 *
 * `active` gates the whole thing — when the island is not showing media this
 * stops updating entirely.
 */
Row {
    id: root

    /// 0..1 peak amplitude.
    property real level: 0
    property bool active: false
    property int bars: Config.waveformBars
    property color color: Theme.text

    property real barWidth: 2.5
    property real minHeight: 3
    property real maxHeight: 15

    spacing: 2.5

    /// Fixed per-bar weights and decay times. Deliberately not random: random
    /// values re-rolled per frame look like noise, these look like a meter.
    readonly property var weights: [1.0, 0.68, 0.92, 0.55, 0.8, 0.62]
    readonly property var decays: [110, 175, 135, 210, 155, 190]

    height: maxHeight

    Repeater {
        model: root.bars

        // Fixed-height cell so the bar can centre vertically — a Row only
        // manages x, so bars would otherwise all hang from the top edge.
        delegate: Item {
            id: cell
            required property int index

            readonly property real weight: root.weights[index % root.weights.length]
            readonly property int decay: root.decays[index % root.decays.length]

            width: root.barWidth
            height: root.maxHeight

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: cell.width
                radius: width / 2
                color: root.color
                antialiasing: true

                height: {
                    if (!root.active) return root.minHeight;
                    const v = Math.max(0, Math.min(1, root.level * cell.weight * 1.35));
                    return root.minHeight + (root.maxHeight - root.minHeight) * v;
                }

                Behavior on height {
                    enabled: Config.animationsEnabled
                    NumberAnimation {
                        duration: cell.decay
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
