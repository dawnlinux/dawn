import QtQuick
import Quickshell
import qs
import qs.components
import qs.services
import qs.theme

/*
 * The keybind cheatsheet.
 *
 * Ctrl+? — every bind Hyprland knows about that carries a description,
 * including anything you added in ~/.config/dawn/local.lua.
 *
 * Navigation is j/k as well as the arrows. This is a list you scan while your
 * hands are already on the keyboard looking for something you have forgotten;
 * reaching for the arrow keys to find out how to avoid reaching for the mouse
 * would be a poor joke.
 */
Item {
    id: root

    implicitWidth: Config.keybindsWidth
    implicitHeight: header.height + divider.height + list.height + Theme.spacingSm * 3

    focus: true
    Component.onCompleted: forceActiveFocus()

    // ── Header ────────────────────────────────────────────────────────────

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingSm
        height: Config.keybindsHeaderHeight

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingSm
            anchors.verticalCenter: parent.verticalCenter
            text: "Keybindings"
            color: Theme.text
            font.pixelSize: Typography.body
            font.weight: Font.Medium
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingSm
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.textTertiary
            font.pixelSize: Typography.caption
            text: {
                if (Keybinds.loading)
                    return "reading…";
                if (Keybinds.error !== "")
                    return Keybinds.error;
                return (Keybinds.selected + 1) + " / " + Keybinds.binds.length;
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm
        height: 1
        color: Theme.border
    }

    // ── The binds ─────────────────────────────────────────────────────────

    ListView {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: Theme.spacingSm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spacingSm
        anchors.rightMargin: Theme.spacingSm

        height: Math.min(Keybinds.binds.length, Config.keybindsMaxRows) * Config.keybindsRowHeight

        clip: true
        model: Keybinds.binds
        currentIndex: Keybinds.selected
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

            readonly property bool active: index === Keybinds.selected

            width: list.width
            height: Config.keybindsRowHeight

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: Theme.radiusSm
                color: row.active ? Theme.surfaceHigh : "transparent"
            }

            // ── The chords ────────────────────────────────────────────────
            //
            // Left-aligned in a fixed-width column so every description starts
            // at the same place. A ragged left edge on a reference list is
            // much harder to scan.
            //
            // One action can have several chords — Dawn binds both the arrows
            // and hjkl to the same moves — so alternatives are shown on the
            // same row, separated by a thin "or".
            Row {
                id: chord
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSm
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                clip: true
                width: Config.keybindsChordWidth - Theme.spacingSm

                Repeater {
                    model: row.modelData.chords

                    delegate: Row {
                        required property int index
                        required property var modelData
                        spacing: 4

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: index > 0
                            text: "or"
                            color: Theme.textQuaternary
                            font.pixelSize: Typography.caption
                        }

                        Repeater {
                            model: modelData.mods
                            delegate: Key { text: modelData; dim: true }
                        }

                        Key { text: modelData.key }
                    }
                }
            }

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingSm + Config.keybindsChordWidth
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingSm
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.description
                color: row.active ? Theme.text : Theme.textSecondary
                font.pixelSize: Typography.body
                elide: Text.ElideRight
            }
        }
    }

    // ── One key cap ───────────────────────────────────────────────────────

    component Key: Rectangle {
        property alias text: label.text
        property bool dim: false

        implicitWidth: label.implicitWidth + Theme.spacingSm
        implicitHeight: Typography.caption + 8
        radius: Theme.radiusSm
        color: dim ? Theme.surface : Theme.surfaceHighest

        Label {
            id: label
            anchors.centerIn: parent
            color: parent.dim ? Theme.textTertiary : Theme.text
            font.pixelSize: Typography.caption
            font.family: Typography.monoFamily
        }
    }

    // ── Keyboard ──────────────────────────────────────────────────────────

    Keys.onEscapePressed: Keybinds.hide()
    Keys.onUpPressed: Keybinds.move(-1)
    Keys.onDownPressed: Keybinds.move(1)

    Keys.onPressed: function (event) {
        switch (event.key) {
        // j/k, as asked for and as the rest of the keyboard-driven world
        // expects. Checked before the modifier-bearing cases so a bare j is
        // never mistaken for anything else.
        case Qt.Key_J:
            Keybinds.move(1);
            event.accepted = true;
            break;
        case Qt.Key_K:
            Keybinds.move(-1);
            event.accepted = true;
            break;

        // Ctrl+D / Ctrl+U — half-page, the vim spelling.
        case Qt.Key_D:
            if (event.modifiers & Qt.ControlModifier) {
                Keybinds.page(1);
                event.accepted = true;
            }
            break;
        case Qt.Key_U:
            if (event.modifiers & Qt.ControlModifier) {
                Keybinds.page(-1);
                event.accepted = true;
            }
            break;

        case Qt.Key_G:
            // gg / G, near enough: Shift+G to the end, plain g to the start.
            if (event.modifiers & Qt.ShiftModifier)
                Keybinds.last();
            else
                Keybinds.first();
            event.accepted = true;
            break;

        case Qt.Key_Home:
            Keybinds.first();
            event.accepted = true;
            break;
        case Qt.Key_End:
            Keybinds.last();
            event.accepted = true;
            break;

        // Any of the ways people close a thing.
        case Qt.Key_Q:
            Keybinds.hide();
            event.accepted = true;
            break;
        }
    }

    // ── Footer ────────────────────────────────────────────────────────────

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        text: "j / k  move     g / G  ends     esc  close"
        color: Theme.textQuaternary
        font.pixelSize: Typography.caption
        visible: Keybinds.binds.length > 0
    }
}
