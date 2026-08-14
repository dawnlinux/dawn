import QtQuick
import Quickshell
import qs
import qs.theme
import qs.components
import qs.services

/*
 * Workspace switch.
 *
 * Dots for the workspaces that exist, with the focused one stretched into a
 * pill, and the name beside it. The stretch is animated rather than the dots
 * being redrawn, so switching left or right reads as the highlight *moving*
 * — which is the information you actually want from a workspace indicator.
 */
Item {
    id: root

    implicitWidth: Math.max(Config.islandWidth + 30, content.implicitWidth + Theme.padH * 2)
    implicitHeight: Config.pillHeight

    Row {
        id: content
        anchors.centerIn: parent
        height: parent.height
        spacing: Theme.spacing

        Row {
            id: dots
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: Hypr.occupied

                delegate: Rectangle {
                    id: dot
                    required property var modelData

                    readonly property bool focused: modelData === Hypr.workspaceId

                    width: focused ? 20 : 7
                    height: 7
                    radius: height / 2
                    color: focused ? Theme.accent : Theme.surfaceHighest
                    antialiasing: true

                    Behavior on width {
                        enabled: Config.animationsEnabled
                        NumberAnimation { duration: Anim.content; easing.type: Easing.OutBack }
                    }
                    ColorBehavior on color {}

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hypr.gotoWorkspace(dot.modelData)
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Hypr.isSpecial ? Hypr.workspaceName
                                 : (Hypr.workspaceName !== "" ? Hypr.workspaceName
                                                              : String(Hypr.workspaceId))
            color: Theme.text
            font.family: Typography.family
            font.pixelSize: Typography.title + 1
            font.weight: Typography.semibold
            font.features: Typography.tabular
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton
        enabled: Config.workspaceClickCommand !== ""
        onClicked: Quickshell.execDetached(["sh", "-c", Config.workspaceClickCommand])
    }
}
