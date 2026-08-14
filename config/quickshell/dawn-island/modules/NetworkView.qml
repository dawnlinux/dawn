import QtQuick
import "root:/"
import "root:/theme"
import "root:/components"
import "root:/services"

/// Connectivity change — connected, disconnected, or moved between wifi and
/// a cable. Only shown on a *transition*; the steady state lives in the
/// expanded panel where it belongs.
Item {
    id: root

    implicitWidth: Math.max(Config.pillWidth, content.implicitWidth + Theme.padH * 2)
    implicitHeight: Config.pillHeight + 8

    Row {
        id: content
        anchors.centerIn: parent
        height: parent.height
        spacing: Theme.spacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Net.kind === "ethernet" ? "ethernet" : "wifi"
            size: 19
            level: Net.strength
            muted: !Net.connected
            color: Net.connected ? Theme.text : Theme.textTertiary
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                width: Math.min(implicitWidth, 240)
                text: Net.label
                color: Theme.text
                font.pixelSize: Typography.title
                font.weight: Typography.semibold
            }

            Label {
                visible: text !== ""
                text: Net.connected ? Net.address : "No connection"
                color: Theme.textTertiary
                font.pixelSize: Typography.caption
                font.features: Typography.tabular
            }
        }
    }
}
