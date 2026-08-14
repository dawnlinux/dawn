import QtQuick
import "root:/"
import "root:/theme"

/*
 * The black body of the notch.
 *
 * Deliberately just the shape — no content, no logic. The illusion depends on
 * three small things:
 *   · square top corners so it grows out of the bezel rather than floating
 *   · a generous bottom radius so it reads as moulded, not cut
 *   · a faint highlight along the bottom edge only, which is where light would
 *     actually catch on a raised black object
 */
Rectangle {
    id: root

    /// True when the island touches the top edge. Drives whether the top
    /// corners are square (notch) or round (floating pill).
    property bool flush: Config.topMargin <= 0

    /// Set by the host so hover can lift the surface very slightly.
    property bool hovered: false

    color: Theme.background
    opacity: Theme.backgroundOpacity

    topLeftRadius: flush ? Config.topCornerRadius : Config.floatingRadius
    topRightRadius: flush ? Config.topCornerRadius : Config.floatingRadius
    bottomLeftRadius: flush ? Config.cornerRadius : Config.floatingRadius
    bottomRightRadius: flush ? Config.cornerRadius : Config.floatingRadius

    antialiasing: true

    FadeBehavior on topLeftRadius {}
    FadeBehavior on topRightRadius {}
    FadeBehavior on bottomLeftRadius {}
    FadeBehavior on bottomRightRadius {}

    // Hairline border. Only meaningful over a light wallpaper, but it costs
    // nothing and stops the island dissolving into a dark one.
    Rectangle {
        anchors.fill: parent
        visible: Theme.showBorder
        color: "transparent"
        radius: 0
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        border.color: Theme.border
        border.width: 1
        antialiasing: true
        opacity: root.hovered ? 1.0 : 0.7
        FadeBehavior on opacity {}
    }

    // Specular catch along the bottom curve.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        visible: Theme.showHighlight
        height: Math.min(parent.height * 0.5, 26)
        color: "transparent"
        bottomLeftRadius: Math.max(0, root.bottomLeftRadius - 1)
        bottomRightRadius: Math.max(0, root.bottomRightRadius - 1)
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Theme.highlight }
        }
        opacity: 0.6
    }
}
