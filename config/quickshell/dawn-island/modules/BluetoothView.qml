import QtQuick
import qs
import qs.theme
import qs.components
import qs.services

/// A device connected or dropped, or the radio was switched on or off. Only
/// shown on a *transition* — the steady state lives in the status panel and the
/// hover panel, where you go looking for it rather than being told.
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
            name: "bluetooth"
            size: 19
            muted: !Bt.powered
            color: Bt.connected ? Theme.text : Theme.textTertiary
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                width: Math.min(implicitWidth, 240)
                text: Bt.label
                color: Theme.text
                font.pixelSize: Typography.title
                font.weight: Typography.semibold
            }

            Label {
                visible: text !== ""
                text: {
                    if (!Bt.powered)
                        return "Radio off";
                    if (!Bt.connected)
                        return "No devices";
                    return Bt.batteryAvailable
                         ? "Connected · " + Bt.batteryPercent + "%"
                         : "Connected";
                }
                color: Theme.textTertiary
                font.pixelSize: Typography.caption
                font.features: Typography.tabular
            }
        }
    }
}
