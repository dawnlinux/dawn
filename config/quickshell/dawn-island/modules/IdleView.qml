import QtQuick
import "root:/"
import "root:/theme"
import "root:/components"
import "root:/services"

/*
 * The resting notch: the time, and nothing else.
 *
 * It is tempting to park a status readout here. The reference deliberately
 * doesn't, and that restraint is the whole idea — the island earns attention by
 * being empty most of the time, so that anything appearing in it means
 * something. Everything else lives one hover away.
 */
Item {
    id: root

    implicitWidth: Math.max(Config.islandWidth, label.implicitWidth + Theme.padH * 2)
    implicitHeight: Config.islandHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: Config.showClock ? Clock.time24 : ""
        color: Theme.text
        font.family: Typography.family
        font.pixelSize: Typography.title
        font.weight: Typography.medium
        font.letterSpacing: Typography.trackingTight
        font.features: Typography.tabular
    }
}
