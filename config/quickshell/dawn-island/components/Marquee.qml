import QtQuick
import qs
import qs.theme

/*
 * Single-line text that scrolls only when it does not fit.
 *
 * Ping-pong rather than a continuous ticker: a looping ticker never lets you
 * finish reading the start of a title, and reads as "marquee widget". This
 * pauses at both ends so the title is legible at rest, which is the point.
 *
 * The animation is bound to `active` so it stops dead when the island is not
 * showing this content — a scroll loop is exactly the kind of always-running
 * animation that keeps a shell awake.
 */
Item {
    id: root

    property string text: ""
    property color color: Theme.text
    property int pixelSize: Typography.title
    property int weight: Typography.regular
    property real letterSpacing: 0
    property bool capitalized: false

    /// Scrolling only happens while this is true.
    property bool active: true
    /// Hard cap on width; beyond this the text scrolls.
    property real maxWidth: 240

    property int startDelay: 1600
    property int endDelay: 1300
    /// Pixels per second while scrolling.
    property real speed: 26

    readonly property bool overflowing: label.implicitWidth > maxWidth + 0.5
    readonly property real distance: Math.max(0, label.implicitWidth - width)

    property real offset: 0

    implicitWidth: Math.min(label.implicitWidth, maxWidth)
    implicitHeight: label.implicitHeight
    clip: overflowing

    Text {
        id: label
        x: root.offset
        width: root.overflowing ? implicitWidth : root.width
        text: root.text
        color: root.color
        font.family: Typography.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        font.letterSpacing: root.letterSpacing
        font.capitalization: root.capitalized ? Font.AllUppercase : Font.MixedCase
        elide: root.overflowing ? Text.ElideNone : Text.ElideRight
        maximumLineCount: 1
        verticalAlignment: Text.AlignVCenter
    }

    SequentialAnimation on offset {
        id: scroll
        running: root.overflowing && root.active && Config.animationsEnabled
        loops: Animation.Infinite

        PauseAnimation { duration: root.startDelay }
        NumberAnimation {
            to: -root.distance
            duration: Math.max(300, (root.distance / root.speed) * 1000)
            easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: root.endDelay }
        NumberAnimation {
            to: 0
            duration: Math.max(300, (root.distance / root.speed) * 1000)
            easing.type: Easing.InOutSine
        }
        onRunningChanged: if (!running) root.offset = 0
    }

    // Soft edge so scrolling text dissolves instead of being guillotined.
    // Only correct because the island body is opaque — it fades to the same
    // colour it sits on.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 18
        visible: root.overflowing
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.background }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 12
        visible: root.overflowing && root.offset < -1
        opacity: Math.min(1, -root.offset / 12)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.background }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
