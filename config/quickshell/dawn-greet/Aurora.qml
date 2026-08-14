import QtQuick
import QtQuick.Shapes

/*
 * The drifting field behind the card.
 *
 * Three soft ellipses on radial gradients, each moving on its own period.
 * The periods are deliberately coprime-ish (23s / 31s / 19s) so the composite
 * never visibly repeats — a background that loops on a round number is a
 * background you start watching instead of the login field.
 *
 * Radial-gradient shapes rather than blurred rectangles: a real blur pass over
 * something this large costs more every frame than the entire rest of the
 * greeter, and produces the same picture.
 */
Item {
    id: root

    property color tintA: "#3a4a7a"
    property color tintB: "#6a3a6e"
    property color tintC: "#24506b"

    /// Dimmed while the card is doing something, so the card is unambiguously
    /// the thing to look at.
    property real intensity: 1.0
    Behavior on intensity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    component Blob: Shape {
        id: blob
        property color tint: "#ffffff"
        property real radius: 460
        property real peak: 0.15

        preferredRendererType: Shape.CurveRenderer
        width: radius * 2
        height: radius * 2
        opacity: root.intensity

        ShapePath {
            fillGradient: RadialGradient {
                centerX: blob.radius
                centerY: blob.radius
                centerRadius: blob.radius
                focalX: blob.radius
                focalY: blob.radius
                GradientStop { position: 0.0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.peak) }
                GradientStop { position: 0.45; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.peak * 0.42) }
                GradientStop { position: 1.0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0.0) }
            }
            strokeWidth: -1
            PathAngleArc {
                centerX: blob.radius; centerY: blob.radius
                radiusX: blob.radius; radiusY: blob.radius
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    Blob {
        id: a
        tint: root.tintA
        radius: 520
        peak: 0.17
        x: root.width * 0.24 - radius
        y: root.height * 0.30 - radius

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.42 - a.radius; duration: 23000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.24 - a.radius; duration: 23000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.52 - a.radius; duration: 17000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.30 - a.radius; duration: 17000; easing.type: Easing.InOutSine }
        }
    }

    Blob {
        id: b
        tint: root.tintB
        radius: 440
        peak: 0.14
        x: root.width * 0.78 - radius
        y: root.height * 0.62 - radius

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.60 - b.radius; duration: 31000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.78 - b.radius; duration: 31000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.34 - b.radius; duration: 26000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.62 - b.radius; duration: 26000; easing.type: Easing.InOutSine }
        }
    }

    Blob {
        id: c
        tint: root.tintC
        radius: 380
        peak: 0.13
        x: root.width * 0.52 - radius
        y: root.height * 0.86 - radius

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.38 - c.radius; duration: 19000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.52 - c.radius; duration: 19000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.70 - c.radius; duration: 29000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.86 - c.radius; duration: 29000; easing.type: Easing.InOutSine }
        }
    }

    /// Vignette. Pulls the edges back to true black so the card sits in a hole
    /// rather than floating on a coloured wash.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                centerRadius: Math.max(root.width, root.height) * 0.72
                focalX: root.width / 2
                focalY: root.height / 2
                GradientStop { position: 0.0;  color: "#00000000" }
                GradientStop { position: 0.55; color: "#00000000" }
                GradientStop { position: 1.0;  color: "#e6000000" }
            }
            strokeWidth: -1
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
}
