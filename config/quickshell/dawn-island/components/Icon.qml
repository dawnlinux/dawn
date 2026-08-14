import QtQuick
import QtQuick.Shapes
import "root:/theme"

/*
 * Vector icon set.
 *
 * These are drawn as real geometry rather than font glyphs for two reasons:
 * they stay crisp on a 2x HiDPI panel, and several of them need to encode a
 * *value* (speaker wave count, battery fill, wifi strength) which a static
 * glyph cannot do. Anything not drawn here falls back to a verified Nerd Font
 * glyph, so `name` is never fatal.
 *
 * All geometry is authored on a 24x24 grid and scaled — keeps the numbers
 * legible and the shapes consistent with each other.
 */
Item {
    id: root

    /// One of: play pause next prev speaker sun battery wifi ethernet
    ///         bell copy dot check close. Anything else → glyph fallback.
    property string name: ""
    property real size: 16
    property color color: Theme.text

    /// 0..1 — drives speaker waves, battery fill, wifi bars, sun ray length.
    property real level: 1.0
    property bool charging: false
    property bool muted: false

    /// Used only by the glyph fallback path.
    property string fallbackGlyph: ""

    implicitWidth: size
    implicitHeight: size

    readonly property var _vectorNames: [
        "play", "pause", "next", "prev", "speaker", "sun",
        "battery", "wifi", "ethernet", "bell", "copy", "dot", "check", "close"
    ]
    readonly property bool isVector: _vectorNames.indexOf(name) !== -1

    // ── Glyph fallback ────────────────────────────────────────────────────
    Text {
        visible: !root.isVector
        anchors.centerIn: parent
        text: root.fallbackGlyph
        color: root.color
        font.family: Typography.iconFamily
        font.pixelSize: root.size
        renderType: Text.NativeRendering
    }

    // ── Vector grid ───────────────────────────────────────────────────────
    Item {
        id: grid
        visible: root.isVector
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.size / 24

        // — play —
        Shape {
            visible: root.name === "play"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.color
                strokeColor: root.color
                strokeWidth: 2.2
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                startX: 8; startY: 5.5
                PathLine { x: 18.5; y: 12 }
                PathLine { x: 8; y: 18.5 }
                PathLine { x: 8; y: 5.5 }
            }
        }

        // — pause —
        Item {
            visible: root.name === "pause"
            anchors.fill: parent
            Rectangle {
                x: 7.5; y: 5; width: 3.6; height: 14
                radius: 1.6; color: root.color; antialiasing: true
            }
            Rectangle {
                x: 12.9; y: 5; width: 3.6; height: 14
                radius: 1.6; color: root.color; antialiasing: true
            }
        }

        // — next / prev —
        Item {
            visible: root.name === "next" || root.name === "prev"
            anchors.fill: parent
            // Mirror the whole group for `prev` so the geometry is authored once.
            transform: Scale {
                origin.x: 12; origin.y: 12
                xScale: root.name === "prev" ? -1 : 1
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.color
                    strokeColor: root.color
                    strokeWidth: 2.0
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    startX: 6; startY: 6.5
                    PathLine { x: 15; y: 12 }
                    PathLine { x: 6; y: 17.5 }
                    PathLine { x: 6; y: 6.5 }
                }
            }
            Rectangle {
                x: 16.2; y: 6; width: 2.8; height: 12
                radius: 1.4; color: root.color; antialiasing: true
            }
        }

        // — speaker —
        Item {
            visible: root.name === "speaker"
            anchors.fill: parent

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // Cone + baffle as one closed path.
                ShapePath {
                    fillColor: root.color
                    strokeColor: root.color
                    strokeWidth: 1.6
                    joinStyle: ShapePath.RoundJoin
                    startX: 3; startY: 9.5
                    PathLine { x: 6.5; y: 9.5 }
                    PathLine { x: 11.5; y: 5 }
                    PathLine { x: 11.5; y: 19 }
                    PathLine { x: 6.5; y: 14.5 }
                    PathLine { x: 3; y: 14.5 }
                    PathLine { x: 3; y: 9.5 }
                }
            }

            // Three waves, revealed progressively by `level`.
            Repeater {
                model: 3
                Shape {
                    required property int index
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    visible: !root.muted && root.level > index * 0.33
                    opacity: Math.max(0, Math.min(1, (root.level - index * 0.33) * 6))
                    Behavior on opacity { NumberAnimation { duration: Anim.quick } }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root.color
                        strokeWidth: 1.7
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 11.5; centerY: 12
                            radiusX: 3.4 + index * 3.0
                            radiusY: 3.4 + index * 3.0
                            startAngle: -46
                            sweepAngle: 92
                        }
                    }
                }
            }

            // Mute slash.
            Shape {
                anchors.fill: parent
                visible: root.muted
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.color
                    strokeWidth: 1.9
                    capStyle: ShapePath.RoundCap
                    startX: 14.5; startY: 9
                    PathLine { x: 20.5; y: 15 }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.color
                    strokeWidth: 1.9
                    capStyle: ShapePath.RoundCap
                    startX: 20.5; startY: 9
                    PathLine { x: 14.5; y: 15 }
                }
            }
        }

        // — sun (brightness) —
        Item {
            visible: root.name === "sun"
            anchors.fill: parent

            Rectangle {
                anchors.centerIn: parent
                width: 9.5; height: 9.5; radius: width / 2
                color: root.color; antialiasing: true
            }
            // Eight rays; their length tracks the brightness level so the icon
            // itself reads as a value, not just a symbol.
            Repeater {
                model: 8
                Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * 45
                    Rectangle {
                        x: 12 - width / 2
                        y: 1.4
                        width: 1.9
                        height: 2.6 + 1.8 * root.level
                        radius: width / 2
                        color: root.color
                        antialiasing: true
                        Behavior on height { NumberAnimation { duration: Anim.quick } }
                    }
                }
            }
        }

        // — battery —
        Item {
            visible: root.name === "battery"
            anchors.fill: parent

            Rectangle {
                x: 1.5; y: 7; width: 18.5; height: 10
                radius: 3.2
                color: "transparent"
                border.color: root.color
                border.width: 1.5
                opacity: 0.55
                antialiasing: true
            }
            // Terminal nub.
            Rectangle {
                x: 21; y: 10; width: 1.8; height: 4
                radius: 0.9; color: root.color; opacity: 0.55; antialiasing: true
            }
            // Fill.
            Rectangle {
                x: 3.2
                y: 8.7
                width: Math.max(1.4, 15.1 * Math.max(0, Math.min(1, root.level)))
                height: 6.6
                radius: 1.8
                color: root.color
                antialiasing: true
                Behavior on width { NumberAnimation { duration: Anim.content; easing.type: Anim.trackEasing } }
            }
            // Charging bolt, punched over the fill.
            Shape {
                anchors.fill: parent
                visible: root.charging
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: Theme.background
                    strokeColor: Theme.background
                    strokeWidth: 0.8
                    joinStyle: ShapePath.RoundJoin
                    startX: 12.4; startY: 7.4
                    PathLine { x: 8.6; y: 12.6 }
                    PathLine { x: 11.2; y: 12.6 }
                    PathLine { x: 10.0; y: 16.6 }
                    PathLine { x: 13.8; y: 11.2 }
                    PathLine { x: 11.2; y: 11.2 }
                    PathLine { x: 12.4; y: 7.4 }
                }
            }
        }

        // — wifi —
        Item {
            visible: root.name === "wifi"
            anchors.fill: parent

            Repeater {
                model: 3
                Shape {
                    required property int index
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    // Arcs beyond the current signal strength stay visible but
                    // dim, so the icon shows both strength and scale.
                    opacity: root.muted ? 0.25
                                        : (root.level * 3 >= index + 0.5 ? 1.0 : 0.22)
                    Behavior on opacity { NumberAnimation { duration: Anim.content } }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root.color
                        strokeWidth: 1.9
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 12; centerY: 17.5
                            radiusX: 4.2 + index * 3.9
                            radiusY: 4.2 + index * 3.9
                            startAngle: -135
                            sweepAngle: 90
                        }
                    }
                }
            }
            Rectangle {
                x: 12 - width / 2; y: 16.2
                width: 2.7; height: 2.7; radius: width / 2
                color: root.color; antialiasing: true
                opacity: root.muted ? 0.35 : 1.0
            }
            Shape {
                anchors.fill: parent
                visible: root.muted
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.color
                    strokeWidth: 1.8
                    capStyle: ShapePath.RoundCap
                    startX: 4.5; startY: 4.5
                    PathLine { x: 19.5; y: 19.5 }
                }
            }
        }

        // — ethernet —
        Item {
            visible: root.name === "ethernet"
            anchors.fill: parent
            Rectangle {
                x: 4.5; y: 10; width: 15; height: 9
                radius: 2
                color: "transparent"
                border.color: root.color
                border.width: 1.6
                antialiasing: true
            }
            Rectangle {
                x: 10.8; y: 4.5; width: 2.4; height: 5.5
                radius: 1.2; color: root.color; antialiasing: true
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: 7.4 + index * 3.7
                    y: 12.4
                    width: 1.8; height: 3.4
                    radius: 0.9
                    color: root.color
                    antialiasing: true
                }
            }
        }

        // — bell —
        Shape {
            visible: root.name === "bell"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.color
                strokeColor: root.color
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                startX: 12; startY: 3.4
                PathQuad { x: 18.2; y: 10.5; controlX: 18.2; controlY: 4.6 }
                PathLine { x: 18.2; y: 14.4 }
                PathLine { x: 20; y: 17.2 }
                PathLine { x: 4; y: 17.2 }
                PathLine { x: 5.8; y: 14.4 }
                PathLine { x: 5.8; y: 10.5 }
                PathQuad { x: 12; y: 3.4; controlX: 5.8; controlY: 4.6 }
            }
            ShapePath {
                fillColor: root.color
                strokeColor: root.color
                strokeWidth: 1.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 9.9; startY: 18.7
                PathQuad { x: 14.1; y: 18.7; controlX: 12; controlY: 21.4 }
            }
        }

        // — copy —
        Item {
            visible: root.name === "copy"
            anchors.fill: parent
            Rectangle {
                x: 3.5; y: 3.5; width: 12; height: 14
                radius: 2.6
                color: "transparent"
                border.color: root.color
                border.width: 1.6
                opacity: 0.5
                antialiasing: true
            }
            Rectangle {
                x: 8.5; y: 6.5; width: 12; height: 14
                radius: 2.6
                color: Theme.background
                border.color: root.color
                border.width: 1.6
                antialiasing: true
            }
        }

        // — dot —
        Rectangle {
            visible: root.name === "dot"
            anchors.centerIn: parent
            width: 8; height: 8; radius: 4
            color: root.color
            antialiasing: true
        }

        // — check —
        Shape {
            visible: root.name === "check"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 5; startY: 12.5
                PathLine { x: 10; y: 17.2 }
                PathLine { x: 19; y: 7 }
            }
        }

        // — close —
        Shape {
            visible: root.name === "close"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: 2.1
                capStyle: ShapePath.RoundCap
                startX: 6.5; startY: 6.5
                PathLine { x: 17.5; y: 17.5 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: 2.1
                capStyle: ShapePath.RoundCap
                startX: 17.5; startY: 6.5
                PathLine { x: 6.5; y: 17.5 }
            }
        }
    }
}
