import QtQuick
import qs
import qs.theme
import qs.components
import qs.services

/*
 * The keyboard-driven status panel.
 *
 * Waybar's answer to "is bluetooth still connected" is to show you the answer
 * permanently, at the cost of a strip of screen you look at maybe twice an
 * hour. The island's answer is a key: the notch unfolds into the readout, you
 * read it, you toggle something, it folds back.
 *
 * Which means this has to be *drivable*, not just visible. Every row that can
 * be acted on responds to Enter or to Left/Right, the selection is always
 * somewhere, and nothing here needs the pointer — though the pointer works,
 * because a panel that punishes you for reaching for the mouse is its own kind
 * of rude.
 *
 * The rows come from Nav, which decides what this machine actually has. This
 * file only knows how to draw a row, never which rows exist.
 */
Item {
    id: root

    focus: true

    implicitWidth: Config.statusWidth
    implicitHeight: Config.statusHeaderHeight
                    + Nav.count * Config.statusRowHeight
                    + Theme.spacingSm * 2 + 1

    // The panel is opened by a global shortcut, so it has to claim focus the
    // moment it exists — there is no click to do it for us, and without this
    // every keystroke lands on whatever was focused before.
    Component.onCompleted: forceActiveFocus()

    Keys.onEscapePressed: Nav.hide()
    Keys.onUpPressed: Nav.move(-1)
    Keys.onDownPressed: Nav.move(1)
    Keys.onTabPressed: Nav.move(1)
    Keys.onBacktabPressed: Nav.move(-1)
    Keys.onLeftPressed: Nav.adjust(-1)
    Keys.onRightPressed: Nav.adjust(1)
    Keys.onReturnPressed: Nav.activate()
    Keys.onEnterPressed: Nav.activate()
    Keys.onSpacePressed: Nav.activate()

    // Handled here because Qt gives Backspace, the bare modifier and the letter
    // keys no signal of their own; everything else falls through to the
    // handlers above, which is why only these are accepted.
    //
    // hjkl sit alongside the arrows rather than replacing them — the panel has
    // no text field, so the letters are free, and both sets stay live at once.
    // Same axes vim uses: jk down/up the list, hl left/right along a level.
    Keys.onPressed: function (event) {
        switch (event.key) {
        case Qt.Key_Backspace:
            Nav.setEnabled(false);
            event.accepted = true;
            break;
        case Qt.Key_Control:
            Nav.setEnabled(true);
            event.accepted = true;
            break;
        case Qt.Key_J:
            Nav.move(1);
            event.accepted = true;
            break;
        case Qt.Key_K:
            Nav.move(-1);
            event.accepted = true;
            break;
        case Qt.Key_H:
            Nav.adjust(-1);
            event.accepted = true;
            break;
        case Qt.Key_L:
            Nav.adjust(1);
            event.accepted = true;
            break;
        }
    }

    // ── Header ────────────────────────────────────────────────────────────

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.statusHeaderHeight

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            eyebrow: true
            text: "Status"
        }

        // The hints are the whole reason this panel is discoverable. They cost
        // one line and remove the need to remember any of it — and since the
        // verbs differ per row, they have to be per row too.
        Label {
            anchors.right: parent.right
            anchors.rightMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            text: {
                // "bksp" spelled out rather than ⌫: at 9px the glyph is a
                // small box with something in it, which is not a key name.
                if (Nav.currentIsLaunch)
                    return "⏎ open · bksp off · ctrl on · esc";
                if (Nav.currentRow === "volume")
                    return "←→ adjust · bksp mute · ctrl on · esc";
                if (Nav.currentIsLevel)
                    return "←→ adjust · esc";
                return "↑↓ move · esc";
            }
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
    }

    // ── Rows ──────────────────────────────────────────────────────────────

    Column {
        anchors.top: divider.bottom
        anchors.topMargin: Theme.spacingSm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm

        Repeater {
            model: Nav.rows

            delegate: Item {
                id: row
                required property int index
                required property string modelData

                readonly property string kind: modelData
                readonly property bool active: index === Nav.selected
                /// Clicking does what Enter does, so only the rows Enter acts
                /// on take a tap — a click on Brightness should not feel like
                /// it missed.
                readonly property bool actionable:
                    Nav.isLaunch(kind) || kind === "volume"

                width: root.width - Theme.spacingSm * 2
                height: Config.statusRowHeight

                // — What this row is —

                readonly property string iconName: {
                    switch (kind) {
                    case "network":    return Net.kind === "ethernet" ? "ethernet" : "wifi";
                    case "bluetooth":  return "bluetooth";
                    case "battery":    return "battery";
                    case "volume":     return "speaker";
                    case "brightness": return "sun";
                    }
                    return "dot";
                }

                readonly property string title: {
                    switch (kind) {
                    case "network":    return Net.kind === "ethernet" ? "Ethernet" : "Wi-Fi";
                    case "bluetooth":  return "Bluetooth";
                    case "battery":    return "Battery";
                    case "volume":     return "Volume";
                    case "brightness": return "Brightness";
                    }
                    return "";
                }

                /// Drives the icon's own level rendering — wifi bars, battery
                /// fill, speaker waves, sun rays.
                readonly property real level: {
                    switch (kind) {
                    case "network":    return Net.strength;
                    case "battery":    return Power.fraction;
                    case "volume":     return Audio.volume;
                    case "brightness": return Brightness.level;
                    }
                    return 1;
                }

                /// "Off" in the sense the icon understands: struck through,
                /// dimmed, not currently doing its job.
                readonly property bool off: {
                    switch (kind) {
                    case "network":   return !Net.connected;
                    case "bluetooth": return !Bt.powered;
                    case "volume":    return Audio.muted;
                    }
                    return false;
                }

                readonly property color tint: {
                    switch (kind) {
                    case "battery":
                        return Power.critical ? Theme.danger
                             : (Power.low ? Theme.warning
                             : (Power.charging ? Theme.positive : Theme.textSecondary));
                    case "network":
                        return Net.connected ? Theme.textSecondary : Theme.textQuaternary;
                    case "bluetooth":
                        return Bt.connected ? Theme.textSecondary
                             : (Bt.powered ? Theme.textTertiary : Theme.textQuaternary);
                    }
                    return off ? Theme.textQuaternary : Theme.textSecondary;
                }

                readonly property string value: {
                    switch (kind) {
                    case "network":    return Net.label;
                    case "bluetooth":  return Bt.label;
                    case "battery":    return Power.percent + "%";
                    case "volume":     return Audio.muted ? "Muted" : Audio.percent + "%";
                    case "brightness": return Brightness.percent + "%";
                    }
                    return "";
                }

                readonly property string caption: {
                    switch (kind) {
                    case "network":
                        return Net.kind === "wifi" && Net.connected
                             ? Math.round(Net.strength * 100) + "%" : "";
                    case "bluetooth":
                        return Bt.detail;
                    case "battery":
                        // "1h 12m to full" / "Fully charged" / "3h 4m left" —
                        // the charging story in the place you'd look for it.
                        return Power.summary;
                    }
                    return "";
                }

                // — Selection —

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

                // Same accent marker as the launcher's selected result, so one
                // habit covers both panels.
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: row.active ? Config.statusRowHeight - 18 : 0
                    radius: 1.5
                    color: Theme.accent
                    antialiasing: true
                    Behavior on height {
                        enabled: Config.animationsEnabled
                        NumberAnimation { duration: Anim.quick; easing.type: Easing.OutCubic }
                    }
                }

                // — Content —

                Icon {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacing + 2
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.iconName
                    size: 17
                    level: row.level
                    muted: row.off
                    charging: row.kind === "battery" && Power.charging
                    color: row.tint
                }

                Label {
                    id: rowTitle
                    anchors.left: rowIcon.right
                    anchors.leftMargin: Theme.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.title
                    color: Theme.text
                    font.pixelSize: Typography.label + 1
                    font.weight: Typography.semibold
                }

                // Level rows get a track instead of a readout: the number alone
                // says what the volume is, the track says where it sits.
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing + 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Nav.isLevel(row.kind)
                    spacing: Theme.spacingSm

                    LevelBar {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 104
                        value: row.level
                        fillColor: row.off ? Theme.textQuaternary : Theme.text
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        horizontalAlignment: Text.AlignRight
                        text: row.value
                        color: Theme.textSecondary
                        font.pixelSize: Typography.caption
                        font.features: Typography.tabular
                    }
                }

                // Everything else reports in words, with the detail underneath.
                Column {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacing + 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !Nav.isLevel(row.kind)
                    spacing: 1

                    Label {
                        anchors.right: parent.right
                        width: Math.min(implicitWidth, 168)
                        horizontalAlignment: Text.AlignRight
                        text: row.value
                        color: Theme.text
                        font.pixelSize: Typography.label
                        font.weight: Typography.medium
                        font.features: Typography.tabular
                    }

                    Label {
                        anchors.right: parent.right
                        visible: text !== ""
                        width: Math.min(implicitWidth, 168)
                        horizontalAlignment: Text.AlignRight
                        text: row.caption
                        color: Theme.textTertiary
                        font.pixelSize: Typography.caption
                        font.features: Typography.tabular
                    }
                }

                // — Pointer, for the times your hand is already there —

                HoverHandler {
                    id: hover
                    // Moving the mouse moves the selection too, so the panel
                    // never disagrees with itself about what Enter would do.
                    onHoveredChanged: if (hovered) Nav.selected = row.index
                }

                TapHandler {
                    enabled: row.actionable
                    onTapped: {
                        Nav.selected = row.index;
                        Nav.activate();
                    }
                }
            }
        }
    }
}
