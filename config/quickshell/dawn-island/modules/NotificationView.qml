import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.theme
import qs.components
import qs.services

/*
 * A notification, folded into the island.
 *
 * Height is fixed and the body is truncated to fit rather than the banner
 * growing to whatever arrived — a shell that resizes to a 400-word Element
 * message is a shell that covers your screen at random. The full text is still
 * in the notification daemon's history; this is the glance.
 *
 * Left click invokes the notification's default action if it has one and
 * dismisses either way; right click dismisses without acting.
 */
Item {
    id: root

    /// The Notification object from IslandState.payload.
    property var notification: null

    readonly property string appName: notification ? (notification.appName || "Notification") : ""
    readonly property string summary: notification
        ? Notifs.truncate(notification.summary, Config.notificationTitleLength) : ""
    readonly property string bodyText: notification
        ? Notifs.truncate(notification.body, Config.notificationBodyLength) : ""

    /// Notifications may carry an inline image (album art, avatar) or just an
    /// icon name to look up in the theme. Prefer the image when there is one.
    readonly property string imageSource: notification ? (notification.image || "") : ""
    readonly property string iconSource: {
        if (!notification || !notification.appIcon)
            return "";
        return Quickshell.iconPath(notification.appIcon, true);
    }

    implicitWidth: Config.notificationWidth
    implicitHeight: Config.notificationHeight

    // ── Icon ──────────────────────────────────────────────────────────────

    Item {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: Theme.padH
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSize + 8
        height: width

        ArtImage {
            anchors.fill: parent
            visible: root.imageSource !== ""
            source: root.imageSource
            radius: Theme.iconRadius
            fallbackGlyph: Glyphs.bell
        }

        Rectangle {
            anchors.fill: parent
            visible: root.imageSource === ""
            radius: Theme.iconRadius
            color: Theme.surface
            antialiasing: true

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                width: parent.width - 12
                height: width
                // Status, not source: an app can name an icon the theme does
                // not have, which resolves to a path that fails to load.
                visible: status === Image.Ready
                source: root.iconSource
            }

            Icon {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                fallbackGlyph: Glyphs.bell
                size: 17
                color: Theme.textTertiary
            }
        }
    }

    // ── Text ──────────────────────────────────────────────────────────────

    Column {
        anchors.left: badge.right
        anchors.leftMargin: Theme.spacing
        anchors.right: dismiss.left
        anchors.rightMargin: Theme.spacingSm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Label {
            width: parent.width
            text: root.appName
            eyebrow: true
        }

        Label {
            width: parent.width
            text: root.summary
            color: Theme.text
            font.pixelSize: Typography.title
            font.weight: Typography.semibold
        }

        Label {
            width: parent.width
            visible: root.bodyText !== ""
            text: root.bodyText
            color: Theme.textSecondary
            font.pixelSize: Typography.body
            // Two lines: enough for a real message, not enough to become a
            // window. Anything longer is already elided by Notifs.truncate.
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
        }
    }

    // ── Dismiss ───────────────────────────────────────────────────────────

    IconButton {
        id: dismiss
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingSm
        anchors.verticalCenter: parent.verticalCenter
        icon: "close"
        iconSize: 13
        hitPadding: 7
        color: Theme.textTertiary
        onClicked: root.close()
    }

    function close() {
        if (root.notification)
            Notifs.dismiss(root.notification);
        IslandState.clear("notification");
    }

    function invoke() {
        const n = root.notification;
        if (n && n.actions && n.actions.length > 0) {
            const preferred = n.actions.find(a => a.identifier === "default") || n.actions[0];
            if (preferred)
                preferred.invoke();
        }
        root.close();
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (ev) {
            if (ev.button === Qt.RightButton) root.close();
            else root.invoke();
        }
    }
}
