import QtQuick
import qs
import qs.theme
import qs.components
import qs.services

/*
 * The hover / click panel: the reference's two-pane layout.
 *
 *   ┌──────────────────────────────────────────────┐
 *   │ [art]  Title                       23:39     │
 *   │        Album              T F SAT S M        │
 *   │        ARTIST                                │
 *   │        ◁ ▷ ▶ ──────      30 31  1  2 3       │
 *   └──────────────────────────────────────────────┘
 *
 * With nothing playing the media pane is replaced by network / battery /
 * volume, which is the whole of the Waybar replacement story: the same
 * information, but only while you are looking.
 */
Item {
    id: root

    property bool active: true

    readonly property bool hasMedia: Config.enableMedia && Media.hasPlayer

    readonly property real leftWidth:
        Config.expandedWidth - Theme.padH * 2 - clock.implicitWidth - Theme.spacingXl

    implicitWidth: Config.expandedWidth

    // Grows past the configured height when the status rows need it — a laptop
    // with wifi, bluetooth, battery and audio has four rows to show, and
    // clipping one of them off the bottom is worse than a taller panel.
    implicitHeight: hasMedia
                    ? Config.expandedHeight
                    : Math.max(Config.expandedHeight,
                               status.implicitHeight + Theme.padV * 2)

    // ── Left pane ─────────────────────────────────────────────────────────

    MediaPane {
        id: media
        anchors.left: parent.left
        anchors.leftMargin: Theme.padH
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: implicitHeight
        textWidth: root.leftWidth - artSize - Theme.spacing
        active: root.active && root.hasMedia
        visible: root.hasMedia
        opacity: visible ? 1 : 0
        FadeBehavior on opacity {}
    }

    StatusPane {
        id: status
        anchors.left: parent.left
        anchors.leftMargin: Theme.padH + 2
        anchors.verticalCenter: parent.verticalCenter
        height: implicitHeight
        visible: !root.hasMedia
        opacity: visible ? 1 : 0
        FadeBehavior on opacity {}
    }

    // ── Right pane ────────────────────────────────────────────────────────

    ClockPane {
        id: clock
        anchors.right: parent.right
        anchors.rightMargin: Theme.padH
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: implicitHeight
        visible: Config.showClock
    }
}
