import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.theme
import qs.components
import qs.services

/*
 * The session carousel — lock, sleep, log out, restart, shut down.
 *
 * Same path and the same depth ramp as the wallpaper carousel, deliberately:
 * two panels that move identically are one thing to learn. What differs is what
 * a tile *is*. Wallpapers are pictures and the picture is the information; these
 * are verbs, so each tile is an icon and a word on a plain card, and the card
 * has to carry state the wallpaper tiles never needed — armed or not.
 *
 * The confirmation is the reason this file is not just the wallpaper carousel
 * with a different model. A destructive tile turns red and asks again, and the
 * whole panel says so; you cannot power the machine off with a single keypress
 * that arrived while the panel was opening.
 */
Item {
    id: root

    focus: true

    implicitWidth: Config.powerWidth
    implicitHeight: Config.powerHeaderHeight
                    + Config.powerTileHeight + 34
                    + 30

    Component.onCompleted: forceActiveFocus()

    /*
     * Hover must not move the selection until the pointer has had a chance to
     * mean it.
     *
     * The panel unfolds wherever the notch is, which is very often directly
     * under a resting cursor — and a stationary pointer that suddenly has a
     * tile beneath it fires hoverChanged exactly like a deliberate hover does.
     * Without this the panel opens with whatever tile happened to be under the
     * mouse already selected, which on the wallpaper carousel is a shrug and
     * here could put Shut Down one keypress away.
     *
     * Where the selection starts is a safety property, so it is defended.
     */
    property bool pointerArmed: false

    Timer {
        running: true
        interval: 400
        onTriggered: root.pointerArmed = true
    }

    Keys.onEscapePressed: Session.hide()
    Keys.onLeftPressed: Session.move(-1)
    Keys.onRightPressed: Session.move(1)
    Keys.onReturnPressed: Session.activate()
    Keys.onEnterPressed: Session.activate()
    Keys.onTabPressed: Session.move(1)
    Keys.onBacktabPressed: Session.move(-1)

    // hl along the carousel, with jk as synonyms — the axis is horizontal and
    // there is no second one for them to mean. Space is deliberately *not*
    // bound: it is the key most likely to be pressed by accident, and this is
    // the panel where that matters most.
    Keys.onPressed: function (event) {
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_K:
            Session.move(-1);
            event.accepted = true;
            break;
        case Qt.Key_L:
        case Qt.Key_J:
            Session.move(1);
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
        height: Config.powerHeaderHeight

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            eyebrow: true
            text: "Session"
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            // The hint carries the warning. When something is armed it is the
            // loudest text on the panel, which is the correct priority.
            text: Session.currentIsArmed
                  ? "⏎ again to " + Session.labelOf(Session.current).toLowerCase()
                  : "←→ choose · ⏎ select · esc"
            color: Session.currentIsArmed ? Theme.danger : Theme.textQuaternary
            font.pixelSize: Typography.micro
            font.weight: Session.currentIsArmed ? Typography.semibold : Typography.regular
            font.letterSpacing: Typography.trackingWide
            ColorBehavior on color { duration: Anim.quick }
        }
    }

    // ── Carousel ──────────────────────────────────────────────────────────

    PathView {
        id: view
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.powerTileHeight + 34

        model: Session.actions

        interactive: false
        currentIndex: Session.selected
        highlightMoveDuration: 280
        pathItemCount: Math.min(Config.powerVisibleTiles,
                                Math.max(1, Session.count))
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        clip: true

        // Inset by half the width a tile has once the path has scaled it down,
        // so the outermost tiles land fully inside the panel. Running the path
        // to the raw edges slices them in half against the clip, which reads
        // as a rendering bug rather than as depth.
        readonly property real endInset: Config.powerTileWidth * 0.62 / 2 + 4

        path: Path {
            startX: view.endInset
            startY: view.height / 2

            PathAttribute { name: "tileScale";   value: 0.62 }
            PathAttribute { name: "tileOpacity"; value: 0.26 }
            PathAttribute { name: "tileZ";       value: 0 }

            PathLine { x: view.width * 0.5; y: view.height / 2 }

            PathAttribute { name: "tileScale";   value: 1.0 }
            PathAttribute { name: "tileOpacity"; value: 1.0 }
            PathAttribute { name: "tileZ";       value: 20 }

            PathLine { x: view.width - view.endInset; y: view.height / 2 }

            PathAttribute { name: "tileScale";   value: 0.62 }
            PathAttribute { name: "tileOpacity"; value: 0.26 }
            PathAttribute { name: "tileZ";       value: 0 }
        }

        delegate: Item {
            id: tile
            required property int index
            required property string modelData

            readonly property string action: modelData
            readonly property bool active: index === Session.selected
            readonly property bool armed: Session.armed === action
            readonly property bool destructive: Session.isDestructive(action)

            /// Armed is red; selected-and-destructive is a warning; everything
            /// else is the ordinary accent. Three states, three colours, so the
            /// tile never has to be read twice.
            readonly property color tone:
                  armed                    ? Theme.danger
                : (active && destructive)  ? Theme.warning
                : Theme.accent

            width: Config.powerTileWidth
            height: Config.powerTileHeight

            scale: PathView.tileScale === undefined ? 1 : PathView.tileScale
            opacity: PathView.tileOpacity === undefined ? 1 : PathView.tileOpacity
            z: PathView.tileZ === undefined ? 0 : PathView.tileZ

            Rectangle {
                id: card
                anchors.fill: parent
                radius: Theme.radiusLg
                color: tile.armed ? Qt.rgba(Theme.danger.r, Theme.danger.g,
                                            Theme.danger.b, 0.16)
                     : (tile.active ? Theme.surfaceHigh : Theme.surface)
                antialiasing: true
                ColorBehavior on color { duration: Anim.quick }

                Column {
                    anchors.centerIn: parent
                    spacing: 9

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Session.iconOf(tile.action)
                        size: 26
                        color: tile.active ? tile.tone : Theme.textTertiary
                        ColorBehavior on color { duration: Anim.quick }
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Session.labelOf(tile.action)
                        color: tile.active ? Theme.text : Theme.textTertiary
                        font.pixelSize: Typography.label + 1
                        font.weight: Typography.semibold
                    }
                }
            }

            // Selection ring, outside the card so it never crops the label.
            Rectangle {
                anchors.fill: card
                anchors.margins: -3
                radius: Theme.radiusLg + 3
                color: "transparent"
                border.width: 2
                border.color: tile.active ? tile.tone : "transparent"
                antialiasing: true
                ColorBehavior on border.color { duration: Anim.quick }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                // Hovering moves the selection but never arms anything —
                // sweeping the pointer across the panel must stay harmless.
                onHoveredChanged: {
                    if (hovered && root.pointerArmed && !tile.active)
                        Session.selected = tile.index;
                }
            }

            TapHandler {
                // Click-to-select, click-again-to-act, exactly like the
                // wallpaper carousel — and destructive tiles still need their
                // confirming second click on top of that.
                onTapped: {
                    if (tile.active)
                        Session.activate(tile.index);
                    else
                        Session.selected = tile.index;
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real _acc: 0
        onWheel: function (ev) {
            _acc += (ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x) / 120;
            while (_acc >= 1)  { Session.move(-1); _acc -= 1; }
            while (_acc <= -1) { Session.move(1);  _acc += 1; }
        }
    }

    // ── Caption ───────────────────────────────────────────────────────────

    Label {
        anchors.top: view.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4
        text: Session.currentIsArmed
              ? "Press Enter again — this cannot be undone"
              : Session.captionOf(Session.current)
        color: Session.currentIsArmed ? Theme.danger : Theme.textTertiary
        font.pixelSize: Typography.caption
        ColorBehavior on color { duration: Anim.quick }
    }
}
