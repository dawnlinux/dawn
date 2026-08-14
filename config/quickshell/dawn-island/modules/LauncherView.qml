import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.theme
import qs.components
import qs.services

/*
 * The app launcher, living inside the island.
 *
 * This is the thing that makes the island a shell rather than a widget: the
 * same surface that was showing the time a moment ago is now a search field
 * with a list under it. It grows into that shape on the same spring as every
 * other state, so it reads as the notch unfolding rather than as a separate
 * window that happened to appear nearby.
 *
 * The height follows the number of results, so narrowing a query shrinks the
 * island instead of leaving empty rows — the panel is never bigger than what
 * it has to say.
 */
Item {
    id: root

    readonly property int visibleRows:
        Math.min(Launcher.count, Config.launcherMaxRows)

    implicitWidth: Config.launcherWidth
    implicitHeight: Config.launcherSearchHeight
                    + (visibleRows > 0 ? visibleRows * Config.launcherRowHeight
                                         + Theme.spacingSm * 2 + 1
                                       : Theme.spacingSm)

    // ── Search field ──────────────────────────────────────────────────────

    Item {
        id: searchRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.launcherSearchHeight

        Icon {
            id: magnifier
            anchors.left: parent.left
            anchors.leftMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 16
            color: Theme.textTertiary
        }

        TextInput {
            id: field
            anchors.left: magnifier.right
            anchors.leftMargin: Theme.spacing
            anchors.right: parent.right
            anchors.rightMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter

            color: Theme.text
            font.family: Typography.family
            font.pixelSize: Typography.title + 1
            selectionColor: Theme.surfaceHighest
            selectedTextColor: Theme.text
            clip: true

            text: Launcher.query
            onTextChanged: {
                if (Launcher.query !== text) {
                    Launcher.query = text;
                    Launcher.selected = 0;
                }
            }

            // The launcher is opened by a global shortcut, so the field has to
            // claim focus itself the moment it exists — there is no click to
            // do it, and without this every keystroke goes nowhere.
            Component.onCompleted: forceActiveFocus()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                visible: field.text === ""
                text: "Search…"
                color: Theme.textQuaternary
                font: field.font
            }

            Keys.onEscapePressed: Launcher.hide()
            Keys.onDownPressed: Launcher.move(1)
            Keys.onUpPressed: Launcher.move(-1)
            Keys.onReturnPressed: Launcher.activate()
            Keys.onEnterPressed: Launcher.activate()
            Keys.onTabPressed: Launcher.move(1)
            Keys.onBacktabPressed: Launcher.move(-1)
        }
    }

    // Hairline under the search field, only once there is a list to divide it
    // from — a rule floating above nothing looks like a mistake.
    Rectangle {
        id: divider
        anchors.top: searchRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.padH
        anchors.rightMargin: Theme.padH
        height: 1
        color: Theme.border
        visible: root.visibleRows > 0
    }

    // ── Results ───────────────────────────────────────────────────────────

    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: Theme.spacingSm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingSm
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm

        clip: true
        model: Launcher.results
        currentIndex: Launcher.selected
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        // Keeps the keyboard selection on screen when it walks off the end.
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: height

        delegate: Item {
            id: row
            required property int index
            required property var modelData

            readonly property bool active: index === Launcher.selected

            width: list.width
            height: Config.launcherRowHeight

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: Theme.radius
                color: row.active ? Theme.surfaceHigh
                     : (hover.hovered ? Theme.surface : "transparent")
                antialiasing: true
                ColorBehavior on color { duration: Anim.quick }
            }

            // Accent bar on the selected row, matching the reference. Animated
            // in height so moving the selection reads as the marker sliding
            // rather than blinking on and off.
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: row.active ? Config.launcherRowHeight - 18 : 0
                radius: 1.5
                color: Theme.accent
                antialiasing: true
                Behavior on height {
                    enabled: Config.animationsEnabled
                    NumberAnimation { duration: Anim.quick; easing.type: Easing.OutCubic }
                }
            }

            IconImage {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing + 2
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 26
                source: {
                    const e = row.modelData ? row.modelData.entry : null;
                    return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
                }
                // Keyed off load status, not off the source string. Plenty of
                // desktop entries name an icon that the current theme does not
                // actually provide; those resolve to a path that then fails to
                // load, so checking `source !== ""` leaves a silent hole in the
                // row where an icon should be.
                visible: status === Image.Ready
            }

            // Falls back to the app's initial, so a missing icon leaves a
            // deliberate-looking tile instead of a gap.
            Rectangle {
                anchors.centerIn: appIcon
                width: 26
                height: 26
                radius: Theme.radiusSm
                color: Theme.surfaceHighest
                visible: appIcon.status !== Image.Ready
                antialiasing: true

                Text {
                    anchors.centerIn: parent
                    text: row.modelData ? row.modelData.name.charAt(0).toUpperCase() : "?"
                    color: Theme.textSecondary
                    font.family: Typography.family
                    font.pixelSize: Typography.label
                    font.weight: Typography.semibold
                }
            }

            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: Theme.spacing
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Label {
                    width: parent.width
                    text: row.modelData ? row.modelData.name : ""
                    color: Theme.text
                    font.pixelSize: Typography.label + 1
                    font.weight: Typography.semibold
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    text: row.modelData ? row.modelData.subtitle : ""
                    color: Theme.textTertiary
                    font.pixelSize: Typography.caption
                }
            }

            HoverHandler {
                id: hover
                // Moving the mouse moves the keyboard selection too, so the
                // two never disagree about what Enter would launch.
                onHoveredChanged: if (hovered) Launcher.selected = row.index
            }

            TapHandler {
                onTapped: Launcher.activate(row.index)
            }
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────

    Label {
        anchors.top: searchRow.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingSm
        visible: Launcher.count === 0 && Launcher.query !== ""
        text: "No matches"
        color: Theme.textQuaternary
        font.pixelSize: Typography.label
    }
}
