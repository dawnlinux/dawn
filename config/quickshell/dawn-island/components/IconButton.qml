import QtQuick
import "root:/"
import "root:/theme"

/*
 * Transport / action button.
 *
 * The press feedback is deliberately faster than the release (90ms down,
 * ~220ms back) — input should feel instant even when the return is soft.
 */
Item {
    id: root

    property string icon: ""
    property string glyph: ""
    property real iconSize: Typography.iconLg
    property color color: Theme.text
    property real level: 1.0
    property bool charging: false
    property bool muted: false

    /// Greys out and stops accepting input.
    property bool enabled: true
    /// Circular wash behind the icon on hover.
    property bool showHoverBackground: true
    property real hitPadding: 7

    signal clicked()
    signal rightClicked()

    readonly property bool hovered: mouse.containsMouse

    implicitWidth: iconSize + hitPadding * 2
    implicitHeight: iconSize + hitPadding * 2

    opacity: enabled ? 1.0 : 0.32
    FadeBehavior on opacity {}

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: Theme.surfaceHigh
        antialiasing: true
        opacity: root.showHoverBackground && root.hovered && root.enabled ? 0.85 : 0
        FadeBehavior on opacity { duration: Anim.quick }
    }

    Icon {
        id: glyphIcon
        anchors.centerIn: parent
        name: root.icon
        fallbackGlyph: root.glyph
        size: root.iconSize
        color: root.color
        level: root.level
        charging: root.charging
        muted: root.muted

        scale: mouse.pressed && root.enabled ? 0.84
             : (root.hovered && root.enabled ? 1.07 : 1.0)

        Behavior on scale {
            enabled: Config.animationsEnabled
            NumberAnimation {
                duration: mouse.pressed ? 90 : 220
                easing.type: mouse.pressed ? Easing.OutQuad : Easing.OutBack
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (ev) {
            if (ev.button === Qt.RightButton) root.rightClicked();
            else root.clicked();
        }
    }
}
