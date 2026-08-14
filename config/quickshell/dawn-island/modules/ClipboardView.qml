import QtQuick
import qs
import qs.theme
import qs.components
import qs.services

/*
 * "Copied" plus a preview.
 *
 * Anything that pattern-matches as a credential arrives here already stripped
 * of its preview (see services/Clipboard.qml) and is shown as a redacted chip.
 * This text renders full width on a screen that may well be shared or
 * recorded, so the default is to say nothing rather than to say too much.
 */
Item {
    id: root

    /// { preview: string, sensitive: bool } from IslandState.payload.
    property var entry: null

    readonly property bool sensitive: entry ? !!entry.sensitive : false
    readonly property string preview: entry && entry.preview ? entry.preview : ""

    implicitWidth: Math.max(Config.pillWidth, content.implicitWidth + Theme.padH * 2)
    implicitHeight: Config.pillHeight + 8

    Row {
        id: content
        anchors.centerIn: parent
        height: parent.height
        spacing: Theme.spacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "copy"
            size: 17
            color: Theme.textSecondary
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                text: "Copied"
                eyebrow: true
            }

            Label {
                visible: !root.sensitive && root.preview !== ""
                width: Math.min(implicitWidth, 300)
                text: root.preview
                color: Theme.text
                font.pixelSize: Typography.label + 1
                font.family: Typography.monoFamily
            }

            // Redacted chip. Deliberately shaped like content so the layout
            // doesn't jump, but carrying none of it.
            Rectangle {
                visible: root.sensitive
                width: hidden.implicitWidth + 14
                height: hidden.implicitHeight + 5
                radius: Theme.radiusSm
                color: Theme.surfaceHigh
                antialiasing: true

                Label {
                    id: hidden
                    anchors.centerIn: parent
                    text: "hidden — looks sensitive"
                    color: Theme.textTertiary
                    font.pixelSize: Typography.caption
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Clipboard.openPicker()
    }
}
