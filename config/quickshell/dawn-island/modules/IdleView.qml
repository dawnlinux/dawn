import QtQuick
import qs
import qs.theme
import qs.components
import qs.services

/*
 * The resting notch: an Arch logo and the time.
 *
 * It is tempting to park a status readout here. The reference deliberately
 * doesn't, and that restraint is the whole idea — the island earns attention by
 * being empty most of the time, so anything appearing in it means something.
 * Everything else lives one hover away.
 *
 * The logo doubles as the launcher button, which is the one affordance worth
 * having permanently visible: it is where every other desktop puts the menu.
 */
Item {
    id: root

    signal logoClicked()

    implicitWidth: Math.max(Config.islandWidth, content.implicitWidth + Theme.padH * 2)
    implicitHeight: Config.islandHeight

    Row {
        id: content
        anchors.centerIn: parent
        height: parent.height
        spacing: Theme.spacingXs

        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.showDistroLogo
            // Padded well past the mark itself — a 14px hit target is a dare.
            width: Config.showDistroLogo ? logo.size + 8 : 0
            height: parent.height

            Icon {
                id: logo
                anchors.centerIn: parent
                name: "arch"
                size: 14
                color: Theme.text
                // Sits a hair below the centre: the logo's mass is in its
                // lower half, so aligning the boxes makes it look like it is
                // floating above the time next to it.
                anchors.verticalCenterOffset: 1

                opacity: logoHover.hovered ? 1.0 : 0.85
                scale: logoTap.pressed ? 0.86 : (logoHover.hovered ? 1.1 : 1.0)

                FadeBehavior on opacity { duration: Anim.quick }
                Behavior on scale {
                    enabled: Config.animationsEnabled
                    NumberAnimation {
                        duration: logoTap.pressed ? 70 : 200
                        easing.type: logoTap.pressed ? Easing.OutQuad : Easing.OutBack
                    }
                }
            }

            HoverHandler {
                id: logoHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: logoTap
                onTapped: root.logoClicked()
            }
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.showClock
            text: Clock.time24
            color: Theme.text
            font.family: Typography.family
            font.pixelSize: Typography.title
            font.weight: Typography.medium
            font.letterSpacing: Typography.trackingTight
            font.features: Typography.tabular
        }
    }
}
