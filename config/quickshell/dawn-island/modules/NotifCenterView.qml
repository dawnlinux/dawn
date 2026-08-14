import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.theme
import qs.components
import qs.services

/*
 * The notification centre.
 *
 * Until now a notification lived for four and a half seconds and was then gone
 * for good — fine for a volume change, indefensible for a message that arrived
 * while something was fullscreen. This is the other half: the same events, kept,
 * and reachable on purpose rather than by luck.
 *
 * The verbs are the status panel's, deliberately. `⏎` runs the notification's
 * default action, `Backspace` dismisses one, `Shift+Backspace` clears the lot.
 * Learning the island once should be enough to drive all of it.
 *
 * Do-not-disturb lives here rather than in the status panel because this is
 * where you look when you want notifications to stop, and because the two
 * facts — "silenced" and "here is what you missed" — belong on one screen.
 */
Item {
    id: root

    focus: true

    readonly property bool empty: Notifs.count === 0
    readonly property int visibleRows:
        Math.min(Notifs.count, Config.notifCenterMaxRows)

    implicitWidth: Config.notifCenterWidth
    implicitHeight: Config.notifCenterHeaderHeight
                    + (root.empty ? 56
                                  : visibleRows * Config.notifCenterRowHeight
                                    + Theme.spacingSm * 2 + 1)

    Component.onCompleted: forceActiveFocus()

    Keys.onEscapePressed: Notifs.hide()
    Keys.onUpPressed: Notifs.move(-1)
    Keys.onDownPressed: Notifs.move(1)
    Keys.onTabPressed: Notifs.move(1)
    Keys.onBacktabPressed: Notifs.move(-1)
    Keys.onReturnPressed: Notifs.invokeSelected()
    Keys.onEnterPressed: Notifs.invokeSelected()

    // jk walk the list alongside the arrows; there is no text field here, so
    // the letters are free and both sets stay live at once.
    Keys.onPressed: function (event) {
        switch (event.key) {
        case Qt.Key_Backspace:
            // Shift is the "and mean it" modifier: one row, or all of them.
            if (event.modifiers & Qt.ShiftModifier) {
                Notifs.clearAll();
                Notifs.hide();
            } else {
                Notifs.dismissSelected();
            }
            event.accepted = true;
            break;
        case Qt.Key_D:
            Notifs.toggleDnd();
            event.accepted = true;
            break;
        case Qt.Key_J:
            Notifs.move(1);
            event.accepted = true;
            break;
        case Qt.Key_K:
            Notifs.move(-1);
            event.accepted = true;
            break;
        }
    }

    // The age labels are only correct while something recomputes them, and
    // only worth recomputing while the panel is actually on screen.
    Timer {
        interval: 30000
        running: Notifs.open
        repeat: true
        onTriggered: ageTick.value = !ageTick.value
    }
    QtObject { id: ageTick; property bool value: false }

    // ── Header ────────────────────────────────────────────────────────────

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.notifCenterHeaderHeight

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSm

            Label {
                anchors.verticalCenter: parent.verticalCenter
                eyebrow: true
                text: "Notifications"
            }

            // Do-not-disturb reads as a state, not a control, because that is
            // what it is: a thing that is currently true about your desktop.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifs.dnd
                width: dndLabel.implicitWidth + 12
                height: 15
                radius: 7.5
                color: Theme.surfaceHighest
                antialiasing: true

                Label {
                    id: dndLabel
                    anchors.centerIn: parent
                    text: "DND"
                    color: Theme.warning
                    font.pixelSize: Typography.micro
                    font.weight: Typography.semibold
                    font.letterSpacing: Typography.trackingWide
                }
            }
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            text: root.empty
                  ? (Notifs.dnd ? "d unsilence · esc" : "d silence · esc")
                  : "⏎ open · bksp clear · d " + (Notifs.dnd ? "unsilence" : "silence") + " · esc"
            color: Theme.textQuaternary
            font.pixelSize: Typography.micro
            font.letterSpacing: Typography.trackingWide
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.padH
        anchors.rightMargin: Theme.padH
        height: 1
        color: Theme.border
        visible: !root.empty
    }

    // ── List ──────────────────────────────────────────────────────────────

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

        visible: !root.empty
        clip: true
        model: Notifs.recent
        currentIndex: Notifs.selected
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

            readonly property var entry: modelData
            readonly property var notif: entry ? entry.n : null
            readonly property bool active: index === Notifs.selected

            readonly property string appName:
                notif ? (notif.appName || "Notification") : ""
            readonly property string summary:
                notif ? Notifs.truncate(notif.summary, Config.notificationTitleLength) : ""
            readonly property string bodyText:
                notif ? Notifs.truncate(notif.body, Config.notificationBodyLength) : ""
            readonly property bool critical:
                notif && notif.urgency === NotificationUrgency.Critical
            readonly property bool actionable:
                notif && notif.actions && notif.actions.length > 0

            // Rebinds on the timer tick so "4m" does not sit there saying "now"
            // for the rest of the afternoon.
            readonly property string age:
                (ageTick.value, entry) ? Notifs.since(entry.at) : ""

            width: list.width
            height: Config.notifCenterRowHeight

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

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: row.active ? Config.notifCenterRowHeight - 26 : 0
                radius: 1.5
                // Critical keeps its own colour even when selected — the one
                // notification you must not misread is the one you must not
                // have to look twice at.
                color: row.critical ? Theme.danger : Theme.accent
                antialiasing: true
                Behavior on height {
                    enabled: Config.animationsEnabled
                    NumberAnimation { duration: Anim.quick; easing.type: Easing.OutCubic }
                }
            }

            // ── App badge ──

            Rectangle {
                id: badge
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacing + 2
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: Theme.radiusSm
                color: Theme.surfaceHighest
                antialiasing: true

                IconImage {
                    id: appIcon
                    anchors.centerIn: parent
                    width: 19
                    height: 19
                    // Keyed off load status, not the source string: plenty of
                    // apps name an icon the theme does not actually provide.
                    visible: status === Image.Ready
                    source: row.notif && row.notif.appIcon
                            ? Quickshell.iconPath(row.notif.appIcon, true) : ""
                }

                Icon {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    fallbackGlyph: Glyphs.bell
                    size: 15
                    color: row.critical ? Theme.danger : Theme.textTertiary
                }
            }

            // ── Text ──

            Column {
                anchors.left: badge.right
                anchors.leftMargin: Theme.spacing
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing + 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Row {
                    width: parent.width
                    spacing: Theme.spacingSm

                    Label {
                        width: Math.min(implicitWidth, parent.width - 60)
                        text: row.appName
                        eyebrow: true
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "· " + row.age
                        color: Theme.textQuaternary
                        font.pixelSize: Typography.micro
                        font.features: Typography.tabular
                    }

                    // Only shown when Enter would actually do something, so the
                    // hint never promises an action the notification lacks.
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.active && row.actionable
                        text: "· ⏎"
                        color: Theme.textTertiary
                        font.pixelSize: Typography.micro
                    }
                }

                Label {
                    width: parent.width
                    text: row.summary
                    color: row.critical ? Theme.danger : Theme.text
                    font.pixelSize: Typography.label + 1
                    font.weight: Typography.semibold
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    text: row.bodyText
                    color: Theme.textTertiary
                    font.pixelSize: Typography.caption
                }
            }

            HoverHandler {
                id: hover
                onHoveredChanged: if (hovered) Notifs.selected = row.index
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: function (ev) {
                    Notifs.selected = row.index;
                    // Right click dismisses without acting, matching the
                    // transient banner's behaviour.
                    if (ev.button === Qt.RightButton)
                        Notifs.dismissSelected();
                    else
                        Notifs.invokeSelected();
                }
            }
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────

    Column {
        anchors.top: header.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 6
        visible: root.empty
        spacing: 2

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Notifs.dnd ? "Silenced" : "All caught up"
            color: Theme.textSecondary
            font.pixelSize: Typography.title
            font.weight: Typography.medium
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Notifs.dnd ? "Notifications are still being recorded"
                             : "Nothing waiting"
            color: Theme.textQuaternary
            font.pixelSize: Typography.caption
        }
    }
}
