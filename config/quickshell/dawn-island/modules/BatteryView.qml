import QtQuick
import "root:/"
import "root:/theme"
import "root:/components"
import "root:/services"

/// Battery, shown on a warning threshold or when the power source changes.
/// Coloured by severity — this is one of the few places in the shell where
/// colour carries meaning rather than decoration.
Item {
    id: root

    readonly property color tint:
          Power.critical ? Theme.danger
        : Power.low      ? Theme.warning
        : Power.charging ? Theme.positive
        : Theme.text

    implicitWidth: Math.max(Config.pillWidth, content.implicitWidth + Theme.padH * 2)
    implicitHeight: Config.pillHeight + 8

    Row {
        id: content
        anchors.centerIn: parent
        height: parent.height
        spacing: Theme.spacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "battery"
            size: 19
            color: root.tint
            level: Power.fraction
            charging: Power.charging
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                text: Power.percent + "%"
                color: root.tint
                font.pixelSize: Typography.title
                font.weight: Typography.semibold
                font.features: Typography.tabular
            }

            Label {
                visible: text !== ""
                text: Power.summary
                color: Theme.textTertiary
                font.pixelSize: Typography.caption
            }
        }
    }
}
