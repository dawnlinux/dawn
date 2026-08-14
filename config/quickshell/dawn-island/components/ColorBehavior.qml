import QtQuick
import qs
import qs.theme

/// Colour transition. Separate from FadeBehavior because colours need a
/// ColorAnimation — a NumberAnimation silently does nothing useful on them.
Behavior {
    id: root

    property int duration: Anim.content

    enabled: Config.animationsEnabled

    ColorAnimation {
        duration: root.duration
        easing.type: Anim.contentEasing
    }
}
