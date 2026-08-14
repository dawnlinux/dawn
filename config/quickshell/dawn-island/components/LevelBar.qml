import QtQuick
import "root:/"
import "root:/theme"

/*
 * Rounded value track — volume, brightness, media progress.
 *
 * The fill uses a minimum width equal to its own height so that a very low
 * value still renders as a rounded dot rather than a sliver, which is what
 * makes it look designed rather than clamped.
 */
Item {
    id: root

    /// 0..1
    property real value: 0
    property color fillColor: Theme.text
    property color trackColor: Theme.surfaceHighest
    property real thickness: Theme.trackThickness
    /// Set false while dragging/seeking so the fill tracks the pointer exactly.
    property bool animated: true

    implicitHeight: thickness
    implicitWidth: 120

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor
        antialiasing: true
    }

    Rectangle {
        id: fill
        height: parent.height
        radius: height / 2
        color: root.fillColor
        antialiasing: true
        width: {
            const v = Math.max(0, Math.min(1, root.value));
            return v <= 0 ? 0 : Math.max(height, root.width * v);
        }

        Behavior on width {
            enabled: root.animated && Config.animationsEnabled
            NumberAnimation { duration: Anim.content; easing.type: Anim.trackEasing }
        }
        ColorBehavior on color {}
    }
}
