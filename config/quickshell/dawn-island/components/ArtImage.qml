import QtQuick
import Quickshell.Widgets
import "root:/"
import "root:/theme"

/*
 * Album art / notification image with real rounded-corner clipping.
 *
 * Uses Quickshell's ClippingRectangle rather than a mask effect — it clips the
 * child to the rounded border directly, which is both cheaper and free of the
 * halo a MultiEffect mask leaves on a dark background.
 *
 * Falls back to a glyph tile when there is no artwork, so the layout never
 * collapses when a player reports no art.
 */
ClippingRectangle {
    id: root

    property string source: ""
    /// Icon shown when there is no artwork.
    property string fallbackIcon: ""
    property string fallbackGlyph: Glyphs.music
    property real fallbackIconSize: Math.round(width * 0.42)

    readonly property bool hasArt: image.status === Image.Ready && source !== ""

    implicitWidth: Theme.artSize
    implicitHeight: Theme.artSize

    radius: Theme.artRadius
    color: Theme.surface
    antialiasing: true

    // Fallback tile.
    Icon {
        anchors.centerIn: parent
        visible: !root.hasArt
        name: root.fallbackIcon
        fallbackGlyph: root.fallbackGlyph
        size: root.fallbackIconSize
        color: Theme.textQuaternary
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        // Decode at display size — album art is routinely 1000px+ and there is
        // no reason to keep that in memory for a 54px tile.
        sourceSize.width: Math.round(root.width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(root.height * Screen.devicePixelRatio)
        opacity: root.hasArt ? 1 : 0
        FadeBehavior on opacity {}
    }
}
