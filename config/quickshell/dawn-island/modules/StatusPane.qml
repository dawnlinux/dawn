import QtQuick
import qs
import qs.theme
import qs.components
import qs.services

/*
 * What the expanded panel shows when nothing is playing.
 *
 * This is the part that lets the island stand in for a status bar without
 * behaving like one: the same information Waybar would pin permanently to the
 * screen is here, but only while you are actually looking at the island.
 *
 * Rows hide themselves when they have nothing to say, and the pane reports the
 * width of whichever row is widest so the island sizes itself honestly.
 */
Item {
    id: root

    // Reports what the rows actually need rather than a fixed panel height:
    // how many rows there are depends on the machine, and a desktop with no
    // battery should not leave a gap where one would have been.
    implicitWidth: Math.max(150, rows.implicitWidth)
    implicitHeight: rows.implicitHeight

    component StatusRow: Row {
        property alias icon: rowIcon.name
        property alias glyph: rowIcon.fallbackGlyph
        property alias level: rowIcon.level
        property alias muted: rowIcon.muted
        property alias charging: rowIcon.charging
        property alias tint: rowIcon.color
        property alias text: rowLabel.text
        property alias detail: rowDetail.text

        spacing: Theme.spacingSm
        height: 19

        Icon {
            id: rowIcon
            anchors.verticalCenter: parent.verticalCenter
            size: Typography.icon
            color: Theme.textSecondary
        }

        Label {
            id: rowLabel
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.pixelSize: Typography.label
            font.weight: Typography.medium
        }

        Label {
            id: rowDetail
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            // Sink names in particular run long; cap and elide rather than
            // letting one row decide how wide the island is.
            width: Math.min(implicitWidth, 132)
            color: Theme.textTertiary
            font.pixelSize: Typography.caption
            font.features: Typography.tabular
        }
    }

    Column {
        id: rows
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        StatusRow {
            visible: Config.showNetwork && Net.enabled
            icon: Net.kind === "ethernet" ? "ethernet" : "wifi"
            level: Net.strength
            muted: !Net.connected
            tint: Net.connected ? Theme.textSecondary : Theme.textQuaternary
            text: Net.label
            detail: Net.kind === "wifi" && Net.connected
                    ? Math.round(Net.strength * 100) + "%" : ""
        }

        StatusRow {
            visible: Config.showBluetooth && Bt.available
            icon: "bluetooth"
            muted: !Bt.powered
            tint: Bt.connected ? Theme.textSecondary
                : (Bt.powered ? Theme.textTertiary : Theme.textQuaternary)
            text: Bt.label
            detail: Bt.detail
        }

        StatusRow {
            visible: Config.showBattery && Power.available
            icon: "battery"
            level: Power.fraction
            charging: Power.charging
            tint: Power.critical ? Theme.danger
                : (Power.low ? Theme.warning
                : (Power.charging ? Theme.positive : Theme.textSecondary))
            text: Power.percent + "%"
            detail: Power.summary
        }

        StatusRow {
            visible: Audio.ready
            icon: "speaker"
            level: Audio.volume
            muted: Audio.muted
            text: Audio.muted ? "Muted" : Audio.percent + "%"
            detail: Audio.deviceName
        }
    }
}
