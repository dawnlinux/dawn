import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.theme
import qs.components
import qs.services

/*
 * The wallpaper carousel.
 *
 * A grid would have been the obvious shape, and it is the wrong one. A grid
 * asks you to search it — twelve equal tiles, none of them the subject, your
 * eye going corner to corner. A carousel has a subject: the one in the middle
 * is the one you are choosing, the rest are context for where you are in the
 * folder, and moving is a slide rather than a jump between cells.
 *
 * That is also why the neighbours shrink and fade along the path instead of
 * being drawn at full strength: depth is doing the work that a selection
 * outline would otherwise have to do alone, so the outline can stay quiet.
 *
 * Thumbnails are requested at twice the tile size and no larger. The folder is
 * full of 4K photographs; loading them at native resolution to draw them 176px
 * wide is how a wallpaper picker ends up using a gigabyte of RAM.
 */
Item {
    id: root

    focus: true

    readonly property bool empty: Wallpaper.count === 0

    implicitWidth: Config.wallpaperWidth
    implicitHeight: Config.wallpaperHeaderHeight
                    + Config.wallpaperTileHeight + 34
                    + 30

    Component.onCompleted: forceActiveFocus()

    Keys.onEscapePressed: Wallpaper.hide()
    Keys.onLeftPressed: Wallpaper.move(-1)
    Keys.onRightPressed: Wallpaper.move(1)
    Keys.onReturnPressed: Wallpaper.apply()
    Keys.onEnterPressed: Wallpaper.apply()
    Keys.onSpacePressed: Wallpaper.apply()
    // Tab walks it too, for the same reason it walks the launcher.
    Keys.onTabPressed: Wallpaper.move(1)
    Keys.onBacktabPressed: Wallpaper.move(-1)

    // hl alongside the arrows. The carousel's axis is horizontal, so jk move
    // along it as well rather than doing nothing — there is no second axis for
    // them to mean, and a dead key is worse than a synonym.
    Keys.onPressed: function (event) {
        switch (event.key) {
        case Qt.Key_H:
        case Qt.Key_K:
            Wallpaper.move(-1);
            event.accepted = true;
            break;
        case Qt.Key_L:
        case Qt.Key_J:
            Wallpaper.move(1);
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
        height: Config.wallpaperHeaderHeight

        Label {
            anchors.left: parent.left
            anchors.leftMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            eyebrow: true
            text: "Wallpaper"
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.padH
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingSm

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.empty
                text: (Wallpaper.selected + 1) + " / " + Wallpaper.count
                color: Theme.textTertiary
                font.pixelSize: Typography.micro
                font.features: Typography.tabular
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.empty
                text: "·"
                color: Theme.textQuaternary
                font.pixelSize: Typography.micro
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.empty ? "esc" : "←→ browse · ⏎ set · esc"
                color: Theme.textQuaternary
                font.pixelSize: Typography.micro
                font.letterSpacing: Typography.trackingWide
            }
        }
    }

    // ── Carousel ──────────────────────────────────────────────────────────

    PathView {
        id: view
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Config.wallpaperTileHeight + 34
        visible: !root.empty

        model: Wallpaper.items

        // Navigation is keyboard, wheel and click only. Letting PathView drag
        // as well means two things own currentIndex and they fight over it
        // every time the selection animates.
        interactive: false
        currentIndex: Wallpaper.selected
        highlightMoveDuration: 280
        // Never ask the path to hold more tiles than the folder has, or
        // PathView wraps the model and the same image appears twice on screen.
        pathItemCount: Math.min(Config.wallpaperVisibleTiles,
                                Math.max(1, Wallpaper.count))
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        clip: true

        // A straight line with attributes ramped along it. The scale and
        // opacity curves are what make it read as depth rather than as a row
        // of shrunken thumbnails.
        // Inset by half the width a tile has once the path has scaled it down,
        // so the outermost tiles land fully inside the panel rather than being
        // sliced in half against the clip.
        readonly property real endInset: Config.wallpaperTileWidth * 0.58 / 2 + 4

        path: Path {
            startX: view.endInset
            startY: view.height / 2

            PathAttribute { name: "tileScale";   value: 0.58 }
            PathAttribute { name: "tileOpacity"; value: 0.22 }
            PathAttribute { name: "tileZ";       value: 0 }

            PathLine { x: view.width * 0.5; y: view.height / 2 }

            PathAttribute { name: "tileScale";   value: 1.0 }
            PathAttribute { name: "tileOpacity"; value: 1.0 }
            PathAttribute { name: "tileZ";       value: 20 }

            PathLine { x: view.width - view.endInset; y: view.height / 2 }

            PathAttribute { name: "tileScale";   value: 0.58 }
            PathAttribute { name: "tileOpacity"; value: 0.22 }
            PathAttribute { name: "tileZ";       value: 0 }
        }

        delegate: Item {
            id: tile
            required property int index
            required property string modelData

            readonly property bool active: index === Wallpaper.selected
            readonly property bool isApplied: modelData === Wallpaper.applied

            width: Config.wallpaperTileWidth
            height: Config.wallpaperTileHeight

            scale: PathView.tileScale === undefined ? 1 : PathView.tileScale
            opacity: PathView.tileOpacity === undefined ? 1 : PathView.tileOpacity
            z: PathView.tileZ === undefined ? 0 : PathView.tileZ

            ClippingRectangle {
                id: frame
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.surfaceHigh

                Image {
                    id: thumb
                    anchors.fill: parent
                    source: "file://" + tile.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    // Twice the tile, for the HiDPI panel and for the moment
                    // the centred tile is scaled past 1.0 by the spring.
                    sourceSize.width: Config.wallpaperTileWidth * 2
                    sourceSize.height: Config.wallpaperTileHeight * 2

                    // Fade in rather than pop — a folder of large images
                    // decodes over several frames and the pops are visible.
                    opacity: status === Image.Ready ? 1 : 0
                    FadeBehavior on opacity { duration: Anim.content }
                }

                // Anything still decoding gets its initial, so the carousel
                // never shows a hole where a tile should be.
                Label {
                    anchors.centerIn: parent
                    visible: thumb.status !== Image.Ready
                    text: Wallpaper.nameOf(tile.modelData).charAt(0).toUpperCase()
                    color: Theme.textQuaternary
                    font.pixelSize: Typography.title
                    font.weight: Typography.semibold
                }
            }

            // Selection ring. Drawn outside the frame so it never eats a pixel
            // of the image it is pointing at.
            Rectangle {
                anchors.fill: frame
                anchors.margins: -3
                radius: Theme.radius + 3
                color: "transparent"
                border.width: 2
                border.color: tile.active ? Theme.accent : "transparent"
                antialiasing: true
                ColorBehavior on border.color { duration: Anim.quick }
            }

            // On the desktop right now. Worth a mark of its own: the selected
            // tile and the applied tile are different things while you browse.
            Rectangle {
                anchors.top: frame.top
                anchors.right: frame.right
                anchors.margins: 6
                width: 18
                height: 18
                radius: 9
                color: Theme.background
                opacity: tile.isApplied ? 0.92 : 0
                antialiasing: true
                FadeBehavior on opacity { duration: Anim.quick }

                Icon {
                    anchors.centerIn: parent
                    name: "check"
                    size: 11
                    color: Theme.positive
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                // First click selects, a click on the already-selected tile
                // applies — so the pointer can never set a wallpaper you had
                // not looked at yet.
                onTapped: {
                    if (tile.active)
                        Wallpaper.apply(tile.index);
                    else
                        Wallpaper.selected = tile.index;
                }
            }
        }
    }

    // Scrolling the carousel moves it one tile per notch, normalised so a
    // touchpad's many small deltas feel like a mouse wheel's few large ones.
    WheelHandler {
        enabled: !root.empty
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real _acc: 0
        onWheel: function (ev) {
            _acc += (ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x) / 120;
            while (_acc >= 1)  { Wallpaper.move(-1); _acc -= 1; }
            while (_acc <= -1) { Wallpaper.move(1);  _acc += 1; }
        }
    }

    // ── Caption ───────────────────────────────────────────────────────────

    Row {
        anchors.top: view.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4
        spacing: Theme.spacingSm
        visible: !root.empty

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Config.wallpaperWidth - 160)
            text: Wallpaper.currentName
            color: Theme.text
            font.pixelSize: Typography.label + 1
            font.weight: Typography.medium
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: Wallpaper.current === Wallpaper.applied
            text: "· on desktop"
            color: Theme.positive
            font.pixelSize: Typography.caption
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────
    //
    // Opening onto an explanation beats the shortcut appearing to do nothing,
    // which is what a silent early-return would have looked like.

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Config.wallpaperHeaderHeight / 2
        visible: root.empty
        spacing: 3

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No wallpapers found"
            color: Theme.textSecondary
            font.pixelSize: Typography.title
            font.weight: Typography.medium
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Drop images into " + Config.wallpaperDir
            color: Theme.textQuaternary
            font.pixelSize: Typography.caption
        }
    }
}
